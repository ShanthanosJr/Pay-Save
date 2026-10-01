import { Inject, Injectable } from '@nestjs/common';
import { Pool, PoolClient } from 'pg';
import { AppException } from '../common/errors/app.exception';
import { forbiddenRole } from '../circles/circle-role.guard';
import type { Membership } from '../circles/circle-role.guard';
import { CirclesRepository } from '../circles/circles.repository';
import { CirclesService } from '../circles/circles.service';
import { PG_POOL } from '../database/database.module';
import { isUuid, toInt, withTransaction } from '../database/transaction';
import { LedgerService } from '../ledger/ledger.service';
import type {
  ContributionRef,
  LedgerEntry,
  PaymentMethod,
} from '../ledger/ledger.types';
import { RecordContributionDto } from './dto/contributions.dto';

export interface VerifyQueueItem {
  entryId: string;
  reference: string;
  cycleNumber: number;
  subjectUserId: string;
  subjectName: string;
  amountMinor: number;
  method: PaymentMethod | null;
  provider: string | null;
  receiptReference: string | null;
  recordedAt: string;
  actorName: string;
}

const conflict = (code: string, message: string) =>
  new AppException(409, code, message);

@Injectable()
export class ContributionsService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly circles: CirclesService,
    private readonly repo: CirclesRepository,
    private readonly ledger: LedgerService,
  ) {}

  /** Idempotent on (circle, clientEntryId): a replay returns the original with created=false. */
  record(
    m: Membership,
    dto: RecordContributionDto,
  ): Promise<{ entry: LedgerEntry; created: boolean }> {
    return withTransaction(this.pool, async (tx) => {
      const circle = await this.circles.lock(tx, m.circleId);
      const existing = await this.ledger.findByClientEntryId(
        tx,
        circle.id,
        dto.clientEntryId,
      );
      if (existing) {
        if (
          existing.type !== 'contribution_recorded' ||
          existing.actorUserId !== m.userId
        )
          throw conflict('ALREADY_RECORDED', 'This entry id is already used');
        return {
          entry: await this.ledger.getEntry(tx, circle.id, existing.id),
          created: false,
        };
      }

      const subjectUserId = (dto.subjectUserId ?? m.userId).toLowerCase();
      if (subjectUserId !== m.userId && m.role !== 'organizer')
        throw forbiddenRole();
      const members = await this.repo.members(tx, circle.id);
      if (!members.some((x) => x.userId === subjectUserId))
        throw new AppException(404, 'MEMBER_NOT_FOUND', 'Member not found');
      if (circle.status !== 'active')
        throw conflict('CIRCLE_NOT_ACTIVE', 'This circle is not active');

      const cycle = (await this.repo.cycles(tx, circle.id)).find(
        (c) => c.number === dto.cycleNumber,
      );
      const status =
        cycle?.status === 'open'
          ? await this.repo.memberStatus(tx, cycle.id, subjectUserId)
          : null;
      if (!cycle || !status)
        throw conflict('CYCLE_NOT_OPEN', 'This cycle is not open');
      if (status.contributionId)
        throw conflict(
          'ALREADY_RECORDED',
          'A payment is already recorded for this cycle',
        );

      const id = await this.ledger.append(tx, {
        circleId: circle.id,
        cycleId: cycle.id,
        type: 'contribution_recorded',
        subjectUserId,
        actorUserId: m.userId,
        amountMinor: circle.contributionMinor,
        method: dto.method,
        provider: dto.provider || null,
        receiptReference: dto.receiptReference || null,
        clientEntryId: dto.clientEntryId,
        deviceCreatedAt: dto.deviceCreatedAt ?? null,
      });
      return {
        entry: await this.ledger.getEntry(tx, circle.id, id),
        created: true,
      };
    });
  }

  verify(m: Membership, entryId: string): Promise<{ entry: LedgerEntry }> {
    return withTransaction(this.pool, async (tx) => {
      const c = await this.pending(tx, m.circleId, entryId);
      const id = await this.ledger.append(tx, {
        circleId: m.circleId,
        cycleId: c.cycleId,
        type: 'contribution_verified',
        subjectUserId: c.subjectUserId,
        actorUserId: m.userId,
        targetEntryId: c.id,
      });
      return { entry: await this.ledger.getEntry(tx, m.circleId, id) };
    });
  }

  reject(
    m: Membership,
    entryId: string,
    reason: string,
  ): Promise<{ entry: LedgerEntry }> {
    return withTransaction(this.pool, async (tx) => {
      const c = await this.pending(tx, m.circleId, entryId);
      const id = await this.ledger.append(tx, {
        circleId: m.circleId,
        cycleId: c.cycleId,
        type: 'correction',
        subjectUserId: c.subjectUserId,
        actorUserId: m.userId,
        targetEntryId: c.id,
        amountMinor: -c.amountMinor,
        note: reason,
        payload: { kind: 'rejected' },
      });
      return { entry: await this.ledger.getEntry(tx, m.circleId, id) };
    });
  }

  async verifyQueue(m: Membership): Promise<{ items: VerifyQueueItem[] }> {
    const { rows } = await this.pool.query<{
      id: string;
      reference: string;
      cycle_number: number;
      subject_user_id: string;
      subject_name: string;
      amount_minor: string;
      method: PaymentMethod | null;
      method_provider: string | null;
      receipt_reference: string | null;
      created_at: Date;
      actor_name: string;
    }>(
      `SELECT e.id, e.reference, s.cycle_number, e.subject_user_id, su.display_name AS subject_name,
              e.amount_minor, e.method, e.method_provider, e.receipt_reference, e.created_at,
              au.display_name AS actor_name
       FROM v_cycle_member_status s
       JOIN ledger_entries e ON e.id = s.contribution_id
       JOIN users su ON su.id = e.subject_user_id
       JOIN users au ON au.id = e.actor_user_id
       WHERE s.circle_id = $1 AND s.status = 'recorded'
       ORDER BY e.seq`,
      [m.circleId],
    );
    return {
      items: rows.map((r) => ({
        entryId: r.id,
        reference: r.reference,
        cycleNumber: r.cycle_number,
        subjectUserId: r.subject_user_id,
        subjectName: r.subject_name,
        amountMinor: toInt(r.amount_minor),
        method: r.method,
        provider: r.method_provider,
        receiptReference: r.receipt_reference,
        recordedAt: r.created_at.toISOString(),
        actorName: r.actor_name,
      })),
    };
  }

  private async pending(
    tx: PoolClient,
    circleId: string,
    entryId: string,
  ): Promise<ContributionRef> {
    await this.circles.lock(tx, circleId);
    const c = isUuid(entryId)
      ? await this.ledger.findContribution(tx, circleId, entryId)
      : null;
    if (!c) throw new AppException(404, 'ENTRY_NOT_FOUND', 'Entry not found');
    if (c.corrected)
      throw conflict('ENTRY_CORRECTED', 'This entry was already rejected');
    if (c.verified)
      throw conflict('ALREADY_VERIFIED', 'This entry is already verified');
    return c;
  }
}
