import { Inject, Injectable } from '@nestjs/common';
import { Pool } from 'pg';
import { CLOCK } from '../common/clock/clock';
import type { Clock } from '../common/clock/clock';
import { AppException } from '../common/errors/app.exception';
import { PG_POOL } from '../database/database.module';
import { withTransaction } from '../database/transaction';
import { LedgerService } from '../ledger/ledger.service';
import { PayoutsService } from '../payouts/payouts.service';
import { avatarUrl } from '../users/image-type';
import { Membership } from './circle-role.guard';
import { CircleInvitationsRepository } from './circle-invitations.repository';
import { CirclesRepository } from './circles.repository';
import { CirclesService, notAPal } from './circles.service';
import type { CircleDetail, InvitablePal, MyInvitation } from './circles.types';

const conflict = (code: string, message: string, extra = {}) =>
  new AppException(409, code, message, extra);
const invitationNotFound = () =>
  new AppException(404, 'INVITATION_NOT_FOUND', 'Invitation not found');

/**
 * Organizers invite their pals into a draft circle; an invitee joins only
 * by accepting. Seats held by pending invitations count against the size.
 */
@Injectable()
export class CircleInvitationsService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    @Inject(CLOCK) private readonly clock: Clock,
    private readonly repo: CircleInvitationsRepository,
    private readonly circlesRepo: CirclesRepository,
    private readonly circles: CirclesService,
    private readonly ledger: LedgerService,
    private readonly payouts: PayoutsService,
  ) {}

  async invitable(
    m: Membership,
  ): Promise<{ seatsLeft: number; pals: InvitablePal[] }> {
    const circle = await this.circlesRepo.get(this.pool, m.circleId);
    const members = await this.circlesRepo.members(this.pool, m.circleId);
    const pending = await this.repo.pendingCount(this.pool, m.circleId);
    const rows = await this.repo.invitablePals(this.pool, m.circleId, m.userId);
    return {
      seatsLeft: Math.max(
        0,
        (circle?.plannedCycles ?? 0) - members.length - pending,
      ),
      pals: rows.map((r) => ({
        id: r.id,
        fullName: r.name,
        username: r.username,
        avatarUrl: avatarUrl(r.id, r.avatar_updated_at),
        state: r.in_circle
          ? 'member'
          : r.invitation_id
            ? 'invited'
            : 'available',
        invitationId: r.invitation_id,
      })),
    };
  }

  invite(
    m: Membership,
    userIds: string[],
    message: string | undefined,
  ): Promise<CircleDetail> {
    const ids = [...new Set(userIds.map((id) => id.toLowerCase()))];
    return withTransaction(this.pool, async (tx) => {
      const circle = await this.circles.lock(tx, m.circleId);
      if (circle.status !== 'draft')
        throw conflict('CIRCLE_ALREADY_STARTED', 'This circle has started');
      if (ids.includes(m.userId))
        throw new AppException(400, 'SELF', 'You are already in this circle');

      const strangers = await this.repo.notPals(tx, m.userId, ids);
      if (strangers.length > 0)
        throw new AppException(
          403,
          'NOT_A_PAL',
          'You can only invite your pals',
          { userIds: strangers },
        );
      const members = await this.circlesRepo.members(tx, circle.id);
      const inside = ids.filter((id) => members.some((x) => x.userId === id));
      if (inside.length > 0)
        throw conflict('ALREADY_MEMBER', 'Already in this circle', {
          userIds: inside,
        });

      const pending = await this.repo.pendingForCircle(tx, circle.id);
      const fresh = ids.filter((id) => !pending.some((p) => p.id === id));
      const seatsLeft = circle.plannedCycles - members.length - pending.length;
      if (fresh.length > seatsLeft)
        throw conflict('NOT_ENOUGH_SEATS', 'Not enough seats left', {
          seatsLeft,
        });
      await this.repo.insertMany(
        tx,
        circle.id,
        m.userId,
        fresh,
        message?.trim() || null,
      );
      return this.circles.detail(tx, circle.id, m.userId);
    });
  }

  cancel(m: Membership, invitationId: string): Promise<CircleDetail> {
    return withTransaction(this.pool, async (tx) => {
      const inv = await this.repo.lockById(tx, invitationId);
      if (!inv || inv.circle_id !== m.circleId || inv.status !== 'pending')
        throw invitationNotFound();
      await this.repo.setStatus(tx, inv.id, 'cancelled', this.clock.now());
      return this.circles.detail(tx, m.circleId, m.userId);
    });
  }

  async mine(userId: string): Promise<{ invitations: MyInvitation[] }> {
    const rows = await this.repo.mine(this.pool, userId);
    const out: MyInvitation[] = [];
    for (const r of rows) {
      const c = await this.circlesRepo.get(this.pool, r.circle_id);
      if (!c) continue;
      // Each member receives one pot: everyone's contribution for that cycle.
      const seats = c.plannedCycles;
      out.push({
        id: r.id,
        message: r.message,
        invitedAt: r.created_at.toISOString(),
        organizer: {
          id: r.organizer_id,
          fullName: r.organizer_name,
          username: r.organizer_username,
          avatarUrl: avatarUrl(r.organizer_id, r.organizer_avatar_updated_at),
        },
        circle: {
          id: c.id,
          name: c.name,
          contributionMinor: c.contributionMinor,
          interval: c.interval,
          turnRule: c.turnRule,
          plannedCycles: c.plannedCycles,
          collectionMode: c.collectionMode,
          firstDueDate: c.firstDueDate,
          memberCount: r.member_count,
          seatsLeft: Math.max(0, seats - r.member_count),
          payout: {
            count: seats,
            unitMinor: c.contributionMinor,
            totalMinor: seats * c.contributionMinor,
            entryIds: [],
          },
          palsInside: r.pal_names ?? [],
        },
      });
    }
    return { invitations: out };
  }

  accept(
    userId: string,
    invitationId: string,
    share: { methodIds?: string[]; preferredId?: string },
  ): Promise<CircleDetail> {
    return withTransaction(this.pool, async (tx) => {
      const inv = await this.repo.lockById(tx, invitationId);
      if (!inv || inv.invitee_id !== userId || inv.status !== 'pending')
        throw invitationNotFound();
      const circle = await this.circles.lock(tx, inv.circle_id);
      if (circle.status !== 'draft')
        throw conflict('CIRCLE_ALREADY_STARTED', 'This circle has started');
      const members = await this.circlesRepo.members(tx, circle.id);
      if (members.some((x) => x.userId === userId))
        throw conflict('ALREADY_MEMBER', 'You are already in this circle');
      if (members.length >= circle.plannedCycles)
        throw conflict('CIRCLE_FULL', 'This circle is full');
      if (!(await this.repo.arePals(tx, inv.invited_by, userId)))
        throw notAPal();

      await this.circlesRepo.addMember(tx, circle.id, userId, 'member');
      await this.ledger.append(tx, {
        circleId: circle.id,
        type: 'member_added',
        subjectUserId: userId,
        actorUserId: userId,
        payload: { role: 'member', via: 'invitation', invitationId: inv.id },
      });
      await this.repo.setStatus(tx, inv.id, 'accepted', this.clock.now());
      if (share.methodIds?.length) {
        await this.payouts.share(
          tx,
          circle.id,
          userId,
          share.methodIds,
          share.preferredId ?? share.methodIds[0],
        );
      } else {
        await this.payouts.shareDefault(tx, circle.id, userId);
      }
      return this.circles.detail(tx, circle.id, userId);
    });
  }

  async decline(userId: string, invitationId: string): Promise<void> {
    await withTransaction(this.pool, async (tx) => {
      const inv = await this.repo.lockById(tx, invitationId);
      if (!inv || inv.invitee_id !== userId || inv.status !== 'pending')
        throw invitationNotFound();
      await this.repo.setStatus(tx, inv.id, 'declined', this.clock.now());
    });
  }
}
