import { Inject, Injectable } from '@nestjs/common';
import { Pool, PoolClient } from 'pg';
import { CLOCK } from '../common/clock/clock';
import type { Clock } from '../common/clock/clock';
import { AppException } from '../common/errors/app.exception';
import { PG_POOL } from '../database/database.module';
import { Db, withTransaction } from '../database/transaction';
import { LedgerService } from '../ledger/ledger.service';
import { NotificationsService } from '../notifications/notifications.service';
import { PayoutsService } from '../payouts/payouts.service';
import { avatarUrl } from '../users/image-type';
import { CircleInvitationsRepository } from './circle-invitations.repository';
import type { LedgerEntry } from '../ledger/ledger.types';
import { circleNotFound, forbiddenRole, Membership } from './circle-role.guard';
import {
  CircleRecord,
  CirclesRepository,
  CollectionMode,
  CycleRecord,
  MemberRecord,
  MemberStatusRecord,
} from './circles.repository';
import { CircleDetail, CircleSummary, PayTo, Total } from './circles.types';
import { generateJoinCode, normalizeJoinCode } from './domain/join-code';
import { lotteryOrder, newLotterySeed } from './domain/lottery';
import { addDays, dueDateFor, isValidDate, localDate } from './domain/schedule';
import { CreateCircleDto } from './dto/circles.dto';

interface Loaded {
  circle: CircleRecord;
  members: MemberRecord[];
  cycles: CycleRecord[];
  current: CycleRecord | undefined;
  statuses: MemberStatusRecord[];
}

const iso = (d: Date | null): string | null => (d ? d.toISOString() : null);

const conflict = (code: string, message: string) =>
  new AppException(409, code, message);

export const notAPal = () =>
  new AppException(
    403,
    'NOT_A_PAL',
    "Only the organizer's pals can join this circle",
  );

@Injectable()
export class CirclesService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    @Inject(CLOCK) private readonly clock: Clock,
    private readonly repo: CirclesRepository,
    private readonly ledger: LedgerService,
    private readonly payouts: PayoutsService,
    private readonly invitations: CircleInvitationsRepository,
    private readonly notifications: NotificationsService,
  ) {}

  async create(userId: string, dto: CreateCircleDto): Promise<CircleDetail> {
    const today = localDate(this.clock.now());
    if (
      !isValidDate(dto.firstDueDate) ||
      dto.firstDueDate < today ||
      dto.firstDueDate > addDays(today, 365)
    ) {
      throw new AppException(
        400,
        'INVALID_FIRST_DUE_DATE',
        'First due date must be between today and one year from today',
      );
    }
    return withTransaction(this.pool, async (tx) => {
      let circleId: string | null = null;
      for (let attempt = 0; !circleId; attempt++) {
        if (attempt === 10) throw new Error('could not allocate a join code');
        circleId = await this.repo.insert(tx, {
          joinCode: generateJoinCode(),
          name: dto.name,
          contributionMinor: dto.contributionMinor,
          interval: dto.interval,
          turnRule: dto.turnRule,
          plannedCycles: dto.plannedCycles,
          firstDueDate: dto.firstDueDate,
          collectionMode: dto.collectionMode ?? 'direct_to_recipient',
          createdBy: userId,
        });
      }
      await this.repo.addMember(tx, circleId, userId, 'organizer');
      await this.payouts.shareDefault(tx, circleId, userId);
      await this.ledger.append(tx, {
        circleId,
        type: 'member_added',
        subjectUserId: userId,
        actorUserId: userId,
        payload: { role: 'organizer' },
      });
      return this.detail(tx, circleId, userId);
    });
  }

  async list(userId: string): Promise<{ circles: CircleSummary[] }> {
    const ids = await this.repo.circleIdsFor(this.pool, userId);
    const circles: CircleSummary[] = [];
    for (const id of ids) {
      circles.push(this.toSummary(await this.load(this.pool, id), userId));
    }
    return { circles };
  }

  get(m: Membership): Promise<CircleDetail> {
    return this.detail(this.pool, m.circleId, m.userId);
  }

  async join(userId: string, rawCode: string): Promise<CircleDetail> {
    const code = normalizeJoinCode(rawCode);
    const invalid = () =>
      new AppException(404, 'INVALID_JOIN_CODE', 'Join code not recognised');
    if (!code) throw invalid();
    return withTransaction(this.pool, async (tx) => {
      const circle = await this.repo.lockByJoinCode(tx, code);
      if (!circle) throw invalid();
      const members = await this.repo.members(tx, circle.id);
      if (members.some((x) => x.userId === userId))
        throw conflict('ALREADY_MEMBER', 'You are already in this circle');
      if (circle.status !== 'draft')
        throw conflict('CIRCLE_ALREADY_STARTED', 'This circle has started');
      if (members.length >= circle.plannedCycles)
        throw conflict('CIRCLE_FULL', 'This circle is full');
      // Seettu is built on trust: only the organizer's pals may join.
      const organizer = members.find((x) => x.role === 'organizer');
      if (
        !organizer ||
        !(await this.invitations.arePals(tx, organizer.userId, userId))
      )
        throw notAPal();
      await this.repo.addMember(tx, circle.id, userId, 'member');
      await this.payouts.shareDefault(tx, circle.id, userId);
      await this.ledger.append(tx, {
        circleId: circle.id,
        type: 'member_added',
        subjectUserId: userId,
        actorUserId: userId,
        payload: { role: 'member', via: 'join_code' },
      });
      await this.notifications.notify(tx, [
        {
          userId: organizer.userId,
          kind: 'member_joined',
          circleId: circle.id,
          payload: { userId },
        },
      ]);
      return this.detail(tx, circle.id, userId);
    });
  }

  commitLottery(m: Membership): Promise<CircleDetail> {
    return withTransaction(this.pool, async (tx) => {
      const circle = await this.lock(tx, m.circleId);
      if (circle.status !== 'draft')
        throw conflict('CIRCLE_ALREADY_STARTED', 'This circle has started');
      if (circle.turnRule !== 'lottery')
        throw conflict('WRONG_TURN_RULE', 'This circle does not use a lottery');
      const { seed, commitment } = newLotterySeed();
      await this.repo.setLotteryCommitment(
        tx,
        circle.id,
        seed,
        commitment,
        this.clock.now(),
      );
      return this.detail(tx, circle.id, m.userId);
    });
  }

  start(m: Membership, requested?: string[]): Promise<CircleDetail> {
    return withTransaction(this.pool, async (tx) => {
      const circle = await this.lock(tx, m.circleId);
      if (circle.status !== 'draft')
        throw conflict('CIRCLE_ALREADY_STARTED', 'This circle has started');
      const members = await this.repo.members(tx, circle.id);
      if (members.length < 2)
        throw conflict('NOT_ENOUGH_MEMBERS', 'At least 2 members are needed');
      const ids = members.map((x) => x.userId);
      // Everyone receives the pot once, so everyone needs a way to be paid.
      const kinds = await this.payouts.kindsByMember(tx, circle.id);
      const missing = ids.filter((id) => !kinds.has(id));
      if (missing.length > 0)
        throw new AppException(
          409,
          'PAYOUT_DETAILS_MISSING',
          'Every member must share how they get paid before the circle starts',
          { userIds: missing },
        );

      let order: string[];
      const payload: Record<string, unknown> = { rule: circle.turnRule };
      if (circle.turnRule === 'lottery') {
        if (!circle.lotterySeed || !circle.lotteryCommitment)
          throw conflict(
            'LOTTERY_NOT_COMMITTED',
            'Commit the lottery before starting',
          );
        order = lotteryOrder(circle.lotterySeed, ids);
        payload.seed = circle.lotterySeed;
        payload.commitment = circle.lotteryCommitment;
      } else {
        order = (requested ?? []).map((id) => id.toLowerCase());
        const known = new Set(ids);
        if (
          order.length !== ids.length ||
          new Set(order).size !== order.length ||
          !order.every((id) => known.has(id))
        ) {
          throw new AppException(
            400,
            'INVALID_TURN_ORDER',
            'Order must list every member exactly once',
          );
        }
      }
      payload.order = order;

      const now = this.clock.now();
      const first = circle.firstDueDate ?? localDate(now);
      const dueDates = order.map((_, i) =>
        dueDateFor(first, circle.interval, i + 1),
      );
      await this.repo.activate(
        tx,
        circle.id,
        order,
        dueDates,
        now,
        circle.turnRule === 'lottery',
      );
      await this.invitations.cancelPending(tx, circle.id, now);
      await this.ledger.append(tx, {
        circleId: circle.id,
        type: 'turn_order_set',
        actorUserId: m.userId,
        payload,
      });
      await this.notifications.notify(
        tx,
        ids
          .filter((id) => id !== m.userId)
          .map((userId) => ({
            userId,
            kind: 'circle_started' as const,
            circleId: circle.id,
            payload: { turn: order.indexOf(userId) + 1, firstDueDate: first },
          })),
      );
      return this.detail(tx, circle.id, m.userId);
    });
  }

  /** Draft-only settings the organizer can still change. */
  updateSettings(m: Membership, mode: CollectionMode): Promise<CircleDetail> {
    return withTransaction(this.pool, async (tx) => {
      const circle = await this.lock(tx, m.circleId);
      if (circle.status !== 'draft')
        throw conflict('CIRCLE_ALREADY_STARTED', 'This circle has started');
      await this.repo.setCollectionMode(tx, circle.id, mode);
      return this.detail(tx, circle.id, m.userId);
    });
  }

  /** Which of my payment methods this circle may see. */
  sharePayout(
    m: Membership,
    methodIds: string[],
    preferredId: string,
  ): Promise<CircleDetail> {
    return withTransaction(this.pool, async (tx) => {
      const circle = await this.lock(tx, m.circleId);
      if (circle.status === 'completed')
        throw conflict('CIRCLE_COMPLETED', 'This circle has finished');
      await this.payouts.share(tx, circle.id, m.userId, methodIds, preferredId);
      return this.detail(tx, circle.id, m.userId);
    });
  }

  /**
   * Who I pay this cycle and their details. Direct mode: the turn's
   * recipient. Via organizer: members pay the organizer, and the organizer
   * pays the recipient the verified pot. Each reveal is logged.
   */
  async payTo(m: Membership): Promise<PayTo> {
    const { circle, members, current } = await this.load(this.pool, m.circleId);
    if (!current)
      throw conflict('NO_OPEN_CYCLE', 'There is no open cycle to pay');
    const organizer = members.find((x) => x.role === 'organizer');
    const recipient = members.find((x) => x.userId === current.payoutUserId);
    const me = members.find((x) => x.userId === m.userId);
    if (!organizer || !recipient || !me) throw circleNotFound();

    const unit = circle.contributionMinor;
    let payee = recipient;
    let amount: Total = {
      count: 1,
      unitMinor: unit,
      totalMinor: unit,
      entryIds: [],
    };
    if (circle.collectionMode === 'via_organizer') {
      if (m.userId === organizer.userId) {
        const t = await this.repo.cycleTotals(this.pool, current.id);
        amount = {
          count: t.verifiedCount,
          unitMinor: t.unitMinor,
          totalMinor: t.verifiedTotalMinor,
          entryIds: t.verifiedIds,
        };
      } else {
        payee = organizer;
      }
    }
    const youReceive = payee.userId === m.userId;
    const firstName = me.displayName.trim().split(/\s+/)[0] ?? '';
    return {
      cycleNumber: current.number,
      dueDate: current.dueDate,
      collectionMode: circle.collectionMode,
      youReceive,
      payee: {
        id: payee.userId,
        fullName: payee.displayName,
        username: null,
        avatarUrl: avatarUrl(payee.userId, payee.avatarUpdatedAt),
      },
      amount,
      reference: `${circle.publicCode} C${current.number} ${firstName}`.slice(
        0,
        30,
      ),
      methods: youReceive
        ? []
        : await this.payouts.revealFor(this.pool, {
            circleId: circle.id,
            viewerId: m.userId,
            ownerId: payee.userId,
            cycleId: current.id,
          }),
    };
  }

  closeCycle(
    m: Membership,
    numberParam: string,
    acknowledgeUnpaid: number,
  ): Promise<CircleDetail> {
    return withTransaction(this.pool, async (tx) => {
      const circle = await this.lock(tx, m.circleId);
      const cycles = await this.repo.cycles(tx, circle.id);
      const current = cycles.find((c) => c.status === 'open');
      if (
        circle.status !== 'active' ||
        !current ||
        !/^\d+$/.test(numberParam) ||
        current.number !== Number(numberParam)
      ) {
        throw conflict('CYCLE_NOT_OPEN', 'This cycle is not open');
      }
      const totals = await this.repo.cycleTotals(tx, current.id);
      if (totals.awaitingCount > 0)
        throw conflict(
          'PENDING_VERIFICATIONS',
          'Verify or reject recorded payments first',
        );
      if (acknowledgeUnpaid !== totals.unpaidCount)
        throw new AppException(
          409,
          'UNPAID_NOT_ACKNOWLEDGED',
          'Acknowledge the unpaid members to close',
          { unpaidCount: totals.unpaidCount },
        );

      const verified = {
        count: totals.verifiedCount,
        unitMinor: totals.unitMinor,
        totalMinor: totals.verifiedTotalMinor,
        entryIds: totals.verifiedIds,
      };
      await this.ledger.append(tx, {
        circleId: circle.id,
        cycleId: current.id,
        type: 'payout',
        subjectUserId: current.payoutUserId,
        actorUserId: m.userId,
        amountMinor: totals.verifiedTotalMinor || null,
        payload: { verified },
      });
      await this.ledger.append(tx, {
        circleId: circle.id,
        cycleId: current.id,
        type: 'cycle_closed',
        actorUserId: m.userId,
        payload: {
          verified,
          unpaid: { count: totals.unpaidCount, userIds: totals.unpaidUserIds },
          acknowledgeUnpaid,
        },
      });
      const members = await this.repo.members(tx, circle.id);
      await this.notifications.notify(
        tx,
        members
          .filter((x) => x.userId !== m.userId)
          .map((x) => ({
            userId: x.userId,
            kind:
              x.userId === current.payoutUserId
                ? ('payout_due_to_you' as const)
                : ('cycle_closed' as const),
            circleId: circle.id,
            payload: {
              cycleNumber: current.number,
              count: verified.count,
              unitMinor: verified.unitMinor,
              totalMinor: verified.totalMinor,
            },
          })),
      );
      await this.repo.closeCycle(tx, current.id, this.clock.now());
      await this.repo.completeIfNoOpenCycles(tx, circle.id);
      return this.detail(tx, circle.id, m.userId);
    });
  }

  /** A member steps out of a circle that has not started. */
  leave(m: Membership): Promise<void> {
    return withTransaction(this.pool, async (tx) => {
      const circle = await this.lock(tx, m.circleId);
      if (m.role === 'organizer')
        throw conflict('ORGANIZER_CANNOT_LEAVE', 'The organizer cannot leave');
      if (circle.status !== 'draft')
        throw conflict(
          'CIRCLE_ALREADY_STARTED',
          'Ask the organizer to remove you from a running circle',
        );
      await this.repo.removeFromDraft(
        tx,
        circle.id,
        m.userId,
        this.clock.now(),
      );
      await this.ledger.append(tx, {
        circleId: circle.id,
        type: 'member_removed',
        subjectUserId: m.userId,
        actorUserId: m.userId,
        payload: { via: 'left' },
      });
      const organizer = (await this.repo.members(tx, circle.id)).find(
        (x) => x.role === 'organizer',
      );
      if (organizer)
        await this.notifications.notify(tx, [
          {
            userId: organizer.userId,
            kind: 'member_removed',
            circleId: circle.id,
            payload: { userId: m.userId, via: 'left' },
          },
        ]);
    });
  }

  /**
   * Organizer removes a member (FR-05). In a running circle this is only
   * possible before the member's own payout and while they have nothing
   * recorded for the open cycle; the change is recorded against that cycle
   * with a reason, and what they already paid in stays on the record.
   */
  removeMember(
    m: Membership,
    targetId: string,
    reason: string | undefined,
  ): Promise<CircleDetail> {
    const userId = targetId.toLowerCase();
    return withTransaction(this.pool, async (tx) => {
      const circle = await this.lock(tx, m.circleId);
      const members = await this.repo.members(tx, circle.id);
      const target = members.find((x) => x.userId === userId);
      if (!target)
        throw new AppException(404, 'MEMBER_NOT_FOUND', 'Member not found');
      if (target.role === 'organizer')
        throw conflict('ORGANIZER_CANNOT_LEAVE', 'The organizer cannot leave');
      if (circle.status === 'completed')
        throw conflict('CIRCLE_COMPLETED', 'This circle has finished');

      const now = this.clock.now();
      const payload: Record<string, unknown> = { via: 'removed' };
      let cycleId: string | null = null;
      if (circle.status === 'draft') {
        await this.repo.removeFromDraft(tx, circle.id, userId, now);
      } else {
        if (!reason)
          throw new AppException(
            400,
            'REASON_REQUIRED',
            'Give a reason for removing a member from a running circle',
          );
        const cycles = await this.repo.cycles(tx, circle.id);
        const current = cycles.find((c) => c.status === 'open');
        if (!current) throw conflict('CYCLE_NOT_OPEN', 'No open cycle');
        const turn = cycles.find((c) => c.payoutUserId === userId);
        if (!turn || turn.status === 'closed')
          throw conflict(
            'MEMBER_ALREADY_PAID_OUT',
            'This member already received the pot and must keep contributing',
          );
        if (members.length <= 2)
          throw conflict('NOT_ENOUGH_MEMBERS', 'At least 2 members are needed');
        const status = await this.repo.memberStatus(tx, current.id, userId);
        if (status?.contributionId)
          throw conflict(
            'MEMBER_HAS_PAYMENT',
            'Verify or reject this member’s payment for the open cycle first',
          );
        const paidIn = await this.repo.verifiedByMember(tx, circle.id, userId);
        payload.fromCycle = current.number;
        payload.paidIn = {
          count: paidIn.count,
          unitMinor: circle.contributionMinor,
          totalMinor: paidIn.totalMinor,
          entryIds: paidIn.entryIds,
        };
        cycleId = current.id;
        await this.repo.removeFromActive(
          tx,
          circle.id,
          userId,
          current.number,
          now,
        );
      }
      await this.ledger.append(tx, {
        circleId: circle.id,
        cycleId,
        type: 'member_removed',
        subjectUserId: userId,
        actorUserId: m.userId,
        note: reason ?? null,
        payload,
      });
      await this.notifications.notify(tx, [
        {
          userId,
          kind: 'member_removed',
          circleId: circle.id,
          payload: { ...payload, reason: reason ?? null },
        },
      ]);
      return this.detail(tx, circle.id, m.userId);
    });
  }

  async ledgerEntries(
    m: Membership,
    scope: 'mine' | 'all' = 'mine',
  ): Promise<{ entries: LedgerEntry[] }> {
    if (scope === 'all' && m.role !== 'organizer') throw forbiddenRole();
    return {
      entries: await this.ledger.listEntries(
        this.pool,
        m.circleId,
        scope === 'mine' ? m.userId : undefined,
      ),
    };
  }

  async lock(tx: PoolClient, circleId: string): Promise<CircleRecord> {
    const circle = await this.repo.lock(tx, circleId);
    if (!circle) throw circleNotFound();
    return circle;
  }

  async detail(
    db: Db,
    circleId: string,
    userId: string,
  ): Promise<CircleDetail> {
    const loaded = await this.load(db, circleId);
    const { circle, members, cycles, current, statuses } = loaded;
    const totals = current
      ? await this.repo.cycleTotals(db, current.id)
      : undefined;
    const revealed = circle.lotteryRevealedAt !== null;
    const kinds = await this.payouts.kindsByMember(db, circleId);
    const me = members.find((x) => x.userId === userId);
    const isOrganizer = me?.role === 'organizer';
    const pending =
      circle.status === 'draft'
        ? await this.invitations.pendingForCircle(db, circleId)
        : [];
    const missing = members
      .filter((x) => !kinds.has(x.userId))
      .map((x) => x.userId);
    return {
      ...this.toSummary(loaded, userId),
      myPayout: await this.payouts.mySharedSummaries(db, circleId, userId),
      setup: {
        seatsTotal: circle.plannedCycles,
        seatsTaken: members.length,
        pendingInvitations: pending.length,
        membersMissingPayout: missing,
        canStart:
          circle.status === 'draft' &&
          members.length >= 2 &&
          missing.length === 0,
      },
      invitations: isOrganizer
        ? pending.map((p) => ({
            id: p.invitation_id,
            invitedAt: p.created_at.toISOString(),
            person: {
              id: p.id,
              fullName: p.name,
              username: p.username,
              avatarUrl: avatarUrl(p.id, p.avatar_updated_at),
            },
          }))
        : [],
      members: members.map((x) => ({
        userId: x.userId,
        displayName: x.displayName,
        avatarUrl: avatarUrl(x.userId, x.avatarUpdatedAt),
        payout: {
          ready: kinds.has(x.userId),
          kinds: kinds.get(x.userId) ?? [],
        },
        role: x.role,
        payoutPosition: x.payoutPosition,
        isYou: x.userId === userId,
        joinedCycle: x.joinedCycle,
      })),
      cycles: cycles.map((c) => ({
        number: c.number,
        dueDate: c.dueDate,
        status: c.status,
        recipientUserId: c.payoutUserId,
        closedAt: iso(c.closedAt),
      })),
      lottery: {
        commitment: circle.lotteryCommitment,
        seed: revealed ? circle.lotterySeed : null,
        committedAt: iso(circle.lotteryCommittedAt),
        revealedAt: iso(circle.lotteryRevealedAt),
      },
      current:
        current && totals
          ? {
              number: current.number,
              dueDate: current.dueDate,
              members: statuses.map((s) => ({
                userId: s.userId,
                displayName: s.displayName,
                status: s.status,
                contributionEntryId: s.contributionId,
                reference: s.reference,
                method: s.method,
                recordedAt: iso(s.recordedAt),
                verifiedAt: iso(s.verifiedAt),
              })),
              totals: {
                verified: {
                  count: totals.verifiedCount,
                  unitMinor: totals.unitMinor,
                  totalMinor: totals.verifiedTotalMinor,
                  entryIds: totals.verifiedIds,
                },
                awaiting: {
                  count: totals.awaitingCount,
                  unitMinor: totals.unitMinor,
                  totalMinor: totals.awaitingTotalMinor,
                  entryIds: totals.awaitingIds,
                },
                unpaid: {
                  count: totals.unpaidCount,
                  userIds: totals.unpaidUserIds,
                },
                membersDue: totals.membersDue,
                expectedMinor: totals.expectedMinor,
              },
            }
          : null,
    };
  }

  private async load(db: Db, circleId: string): Promise<Loaded> {
    const circle = await this.repo.get(db, circleId);
    if (!circle) throw circleNotFound();
    const members = await this.repo.members(db, circleId);
    const cycles = await this.repo.cycles(db, circleId);
    const current =
      circle.status === 'active'
        ? cycles.find((c) => c.status === 'open')
        : undefined;
    const statuses = current
      ? await this.repo.memberStatuses(db, current.id)
      : [];
    return { circle, members, cycles, current, statuses };
  }

  private toSummary(l: Loaded, userId: string): CircleSummary {
    const { circle, members, current, statuses } = l;
    const me = members.find((x) => x.userId === userId);
    if (!me) throw circleNotFound();
    const mine = statuses.find((s) => s.userId === userId);
    const recipient = current?.payoutUserId
      ? members.find((x) => x.userId === current.payoutUserId)
      : undefined;
    return {
      id: circle.id,
      name: circle.name,
      publicCode: circle.publicCode,
      joinCode: circle.joinCode,
      role: me.role,
      status: circle.status,
      collectionMode: circle.collectionMode,
      contributionMinor: circle.contributionMinor,
      interval: circle.interval,
      turnRule: circle.turnRule,
      plannedCycles: circle.plannedCycles,
      memberCount: members.length,
      firstDueDate: circle.firstDueDate,
      myTurn: me.payoutPosition,
      currentCycle: current
        ? {
            number: current.number,
            dueDate: current.dueDate,
            myStatus: mine?.status ?? null,
            myContribution: mine?.contributionId
              ? {
                  entryId: mine.contributionId,
                  reference: mine.reference,
                  method: mine.method,
                  recordedAt: iso(mine.recordedAt),
                  verifiedAt: iso(mine.verifiedAt),
                }
              : null,
            recipient: recipient
              ? {
                  userId: recipient.userId,
                  displayName: recipient.displayName,
                  isYou: recipient.userId === userId,
                }
              : null,
          }
        : null,
    };
  }
}
