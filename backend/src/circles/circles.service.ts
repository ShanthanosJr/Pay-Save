import { Inject, Injectable } from '@nestjs/common';
import { Pool, PoolClient } from 'pg';
import { CLOCK } from '../common/clock/clock';
import type { Clock } from '../common/clock/clock';
import { AppException } from '../common/errors/app.exception';
import { PG_POOL } from '../database/database.module';
import { Db, withTransaction } from '../database/transaction';
import { LedgerService } from '../ledger/ledger.service';
import type { LedgerEntry } from '../ledger/ledger.types';
import { circleNotFound, forbiddenRole, Membership } from './circle-role.guard';
import {
  CircleRecord,
  CirclesRepository,
  CycleRecord,
  MemberRecord,
  MemberStatusRecord,
} from './circles.repository';
import { CircleDetail, CircleSummary } from './circles.types';
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

@Injectable()
export class CirclesService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    @Inject(CLOCK) private readonly clock: Clock,
    private readonly repo: CirclesRepository,
    private readonly ledger: LedgerService,
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
          createdBy: userId,
        });
      }
      await this.repo.addMember(tx, circleId, userId, 'organizer');
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
      await this.repo.addMember(tx, circle.id, userId, 'member');
      await this.ledger.append(tx, {
        circleId: circle.id,
        type: 'member_added',
        subjectUserId: userId,
        actorUserId: userId,
        payload: { role: 'member', via: 'join_code' },
      });
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
      await this.ledger.append(tx, {
        circleId: circle.id,
        type: 'turn_order_set',
        actorUserId: m.userId,
        payload,
      });
      return this.detail(tx, circle.id, m.userId);
    });
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
      await this.repo.closeCycle(tx, current.id, this.clock.now());
      await this.repo.completeIfNoOpenCycles(tx, circle.id);
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
    return {
      ...this.toSummary(loaded, userId),
      members: members.map((x) => ({
        userId: x.userId,
        displayName: x.displayName,
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
