import { Inject, Injectable } from '@nestjs/common';
import { Pool, PoolClient } from 'pg';
import { forbiddenRole } from '../circles/circle-role.guard';
import type { Membership } from '../circles/circle-role.guard';
import { CirclesRepository } from '../circles/circles.repository';
import { AppException } from '../common/errors/app.exception';
import { PG_POOL } from '../database/database.module';
import { toIntOrNull, withTransaction } from '../database/transaction';
import type { LedgerEntryType, PaymentMethod } from '../ledger/ledger.types';
import { NotificationsService } from '../notifications/notifications.service';

export const DISPUTE_CATEGORIES = [
  'payment_not_recorded',
  'payment_rejected',
  'payout_not_received',
  'other',
] as const;
export type DisputeCategory = (typeof DISPUTE_CATEGORIES)[number];
export type DisputeStatus =
  'awaiting_consent' | 'consented' | 'resolved' | 'declined';

/** Aggregates are only shown for circles at least this large (FR-10). */
export const MIN_COMMUNITY_MEMBERS = 5;

export interface CommunityConsent {
  /** True once every current member has agreed. */
  shared: boolean;
  mine: boolean;
  granted: number;
  needed: number;
  /** Below the minimum size nothing is shown to officers even when shared. */
  largeEnough: boolean;
  minimumMembers: number;
}

export interface MemberDispute {
  id: string;
  category: DisputeCategory;
  status: DisputeStatus;
  createdAt: string;
  raisedByYou: boolean;
  entries: { entryId: string; reference: string }[];
  consent: { needed: number; granted: number; mine: boolean | null };
  resolutionNote: string | null;
  /** Each time an officer opened the evidence. */
  views: string[];
}

export interface OfficerDispute {
  id: string;
  circleCode: string;
  category: DisputeCategory;
  status: DisputeStatus;
  entryCount: number;
  createdAt: string;
}

export interface EvidenceEntry {
  reference: string;
  type: LedgerEntryType;
  cycleNumber: number | null;
  amountMinor: number | null;
  method: PaymentMethod | null;
  createdAt: string;
  /** "Member A", "Member B": stable within one dispute, never a name. */
  subject: string | null;
  recordedBy: string;
  status: 'recorded' | 'verified' | 'corrected' | null;
  hash: string;
}

interface DisputeRow {
  id: string;
  circle_id: string;
  raised_by: string;
  entry_ids: string[];
  status: DisputeStatus;
  category: DisputeCategory;
  created_at: Date;
  resolution_note: string | null;
}

const notFound = () =>
  new AppException(404, 'DISPUTE_NOT_FOUND', 'Dispute not found');

@Injectable()
export class CommunityService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly notifications: NotificationsService,
    private readonly circlesRepo: CirclesRepository,
  ) {}

  // ---------- circle opt-in ----------

  async consent(m: Membership): Promise<CommunityConsent> {
    const { rows } = await this.pool.query<{
      shared: boolean;
      mine: boolean;
      granted: number;
      needed: number;
    }>(
      `SELECT c.community_consent AS shared,
              count(*)::int AS needed,
              count(k.id)::int AS granted,
              COALESCE(bool_or(k.id IS NOT NULL AND m.user_id = $2), false) AS mine
       FROM circles c
       JOIN circle_members m ON m.circle_id = c.id AND m.left_cycle IS NULL
       LEFT JOIN consents k ON k.circle_id = c.id AND k.user_id = m.user_id
            AND k.scope = 'community_aggregates' AND k.revoked_at IS NULL
       WHERE c.id = $1 GROUP BY c.id`,
      [m.circleId, m.userId],
    );
    const r = rows[0];
    return {
      ...r,
      largeEnough: r.needed >= MIN_COMMUNITY_MEMBERS,
      minimumMembers: MIN_COMMUNITY_MEMBERS,
    };
  }

  /** Each member decides for themself; the circle is shared only when all agree. */
  async setConsent(m: Membership, granted: boolean): Promise<CommunityConsent> {
    await withTransaction(this.pool, async (tx) => {
      await tx.query('SELECT 1 FROM circles WHERE id = $1 FOR UPDATE', [
        m.circleId,
      ]);
      if (granted)
        await tx.query(
          `INSERT INTO consents (circle_id, user_id, scope)
           VALUES ($1, $2, 'community_aggregates') ON CONFLICT DO NOTHING`,
          [m.circleId, m.userId],
        );
      else
        await tx.query(
          `UPDATE consents SET revoked_at = now()
           WHERE circle_id = $1 AND user_id = $2 AND scope = 'community_aggregates'
             AND revoked_at IS NULL`,
          [m.circleId, m.userId],
        );
      await this.circlesRepo.syncCommunityConsent(tx, m.circleId);
    });
    return this.consent(m);
  }

  // ---------- disputes: member side ----------

  raise(
    m: Membership,
    entryIds: string[],
    category: DisputeCategory,
  ): Promise<MemberDispute> {
    const ids = [...new Set(entryIds.map((id) => id.toLowerCase()))];
    return withTransaction(this.pool, async (tx) => {
      const { rows: entries } = await tx.query<{
        id: string;
        subject_user_id: string | null;
        target_subject: string | null;
      }>(
        `SELECT e.id, e.subject_user_id, t.subject_user_id AS target_subject
         FROM ledger_entries e LEFT JOIN ledger_entries t ON t.id = e.target_entry_id
         WHERE e.circle_id = $1 AND e.id = ANY($2::uuid[])`,
        [m.circleId, ids],
      );
      if (entries.length !== ids.length)
        throw new AppException(404, 'ENTRY_NOT_FOUND', 'Entry not found');
      // a member may only put records about themself in front of an officer
      if (
        m.role !== 'organizer' &&
        !entries.every(
          (e) =>
            e.subject_user_id === m.userId || e.target_subject === m.userId,
        )
      )
        throw forbiddenRole();

      const { rows } = await tx.query<{ id: string }>(
        `INSERT INTO disputes (circle_id, raised_by, entry_ids, category)
         VALUES ($1, $2, $3::uuid[], $4) RETURNING id`,
        [m.circleId, m.userId, ids, category],
      );
      const disputeId = rows[0].id;
      await this.grant(tx, m.circleId, m.userId, disputeId);
      const needed = await this.neededConsent(tx, m.circleId, ids);
      await this.notifications.notify(
        tx,
        needed
          .filter((userId) => userId !== m.userId)
          .map((userId) => ({
            userId,
            kind: 'dispute_consent_requested' as const,
            circleId: m.circleId,
            payload: { disputeId, category },
          })),
      );
      await this.settle(tx, disputeId, m.circleId, ids);
      return (await this.memberDisputes(tx, m, disputeId))[0];
    });
  }

  async disputes(m: Membership): Promise<{ disputes: MemberDispute[] }> {
    return { disputes: await this.memberDisputes(this.pool, m) };
  }

  /** Saying no ends the request: an officer never sees the entries. */
  respond(
    m: Membership,
    disputeId: string,
    granted: boolean,
  ): Promise<MemberDispute> {
    return withTransaction(this.pool, async (tx) => {
      const { rows } = await tx.query<DisputeRow>(
        'SELECT * FROM disputes WHERE id = $1 AND circle_id = $2 FOR UPDATE',
        [disputeId, m.circleId],
      );
      const d = rows[0];
      if (!d) throw notFound();
      const needed = await this.neededConsent(tx, d.circle_id, d.entry_ids);
      if (!needed.includes(m.userId)) throw notFound();
      if (d.status !== 'awaiting_consent')
        throw new AppException(
          409,
          'DISPUTE_CLOSED',
          'This request is no longer waiting for consent',
        );
      if (granted) {
        await this.grant(tx, d.circle_id, m.userId, d.id);
        await this.settle(tx, d.id, d.circle_id, d.entry_ids);
      } else {
        await tx.query(
          `UPDATE disputes SET status = 'declined' WHERE id = $1`,
          [d.id],
        );
        await this.notifications.notify(
          tx,
          needed
            .filter((u) => u !== m.userId)
            .map((userId) => ({
              userId,
              kind: 'dispute_updated' as const,
              circleId: d.circle_id,
              payload: { disputeId: d.id, status: 'declined' },
            })),
        );
      }
      return (await this.memberDisputes(tx, m, d.id))[0];
    });
  }

  // ---------- officer side: aggregates and consented evidence only ----------

  async overview(): Promise<{
    minimumMembers: number;
    circles: {
      circleCode: string;
      members: number;
      onTimeRatePct: number | null;
      cyclesRun: number;
    }[];
  }> {
    const { rows } = await this.pool.query<{
      public_code: string;
      members: number;
      on_time_rate_pct: string | null;
      cycles_run: number;
    }>(
      `SELECT public_code, members::int, on_time_rate_pct, cycles_run::int
       FROM v_community_circle_health ORDER BY public_code`,
    );
    return {
      minimumMembers: MIN_COMMUNITY_MEMBERS,
      circles: rows.map((r) => ({
        circleCode: r.public_code,
        members: r.members,
        onTimeRatePct: toIntOrNull(r.on_time_rate_pct),
        cyclesRun: r.cycles_run,
      })),
    };
  }

  async officerDisputes(): Promise<{ disputes: OfficerDispute[] }> {
    const { rows } = await this.pool.query<{
      id: string;
      public_code: string;
      category: DisputeCategory;
      status: DisputeStatus;
      entry_count: number;
      created_at: Date;
    }>(
      `SELECT d.id, c.public_code, d.category, d.status,
              cardinality(d.entry_ids) AS entry_count, d.created_at
       FROM disputes d JOIN circles c ON c.id = d.circle_id
       WHERE d.status IN ('consented', 'resolved')
       ORDER BY (d.status = 'consented') DESC, d.created_at DESC LIMIT 100`,
    );
    return {
      disputes: rows.map((r) => ({
        id: r.id,
        circleCode: r.public_code,
        category: r.category,
        status: r.status,
        entryCount: r.entry_count,
        createdAt: r.created_at.toISOString(),
      })),
    };
  }

  /**
   * Only the entries named in a consented dispute, with people replaced by
   * labels. Every call is logged and the people concerned are told.
   */
  evidence(
    officerId: string,
    disputeId: string,
  ): Promise<{ dispute: OfficerDispute; entries: EvidenceEntry[] }> {
    return withTransaction(this.pool, async (tx) => {
      const { rows } = await tx.query<DisputeRow & { public_code: string }>(
        `SELECT d.*, c.public_code FROM disputes d JOIN circles c ON c.id = d.circle_id
         WHERE d.id = $1 AND d.status IN ('consented', 'resolved') FOR UPDATE OF d`,
        [disputeId],
      );
      const d = rows[0];
      if (!d) throw notFound();
      const { rows: entries } = await tx.query<{
        reference: string;
        entry_type: LedgerEntryType;
        cycle_number: number | null;
        amount_minor: string | null;
        method: PaymentMethod | null;
        created_at: Date;
        subject_user_id: string | null;
        actor_user_id: string;
        hash: string;
        status: EvidenceEntry['status'];
      }>(
        `SELECT e.reference, e.entry_type, cy.number AS cycle_number, e.amount_minor, e.method,
                e.created_at, e.subject_user_id, e.actor_user_id, e.hash,
                CASE
                  WHEN e.entry_type <> 'contribution_recorded' THEN NULL
                  WHEN EXISTS (SELECT 1 FROM ledger_entries x WHERE x.target_entry_id = e.id
                                 AND x.entry_type = 'correction') THEN 'corrected'
                  WHEN EXISTS (SELECT 1 FROM ledger_entries x WHERE x.target_entry_id = e.id
                                 AND x.entry_type = 'contribution_verified') THEN 'verified'
                  ELSE 'recorded'
                END AS status
         FROM ledger_entries e LEFT JOIN cycles cy ON cy.id = e.cycle_id
         WHERE e.circle_id = $1 AND e.id = ANY($2::uuid[]) ORDER BY e.seq`,
        [d.circle_id, d.entry_ids],
      );
      const labels = new Map<string, string>();
      const label = (id: string | null) => {
        if (!id) return null;
        if (!labels.has(id))
          labels.set(id, `Member ${String.fromCharCode(65 + labels.size)}`);
        return labels.get(id) as string;
      };
      const out = entries.map((e) => ({
        reference: e.reference,
        type: e.entry_type,
        cycleNumber: e.cycle_number,
        amountMinor: toIntOrNull(e.amount_minor),
        method: e.method,
        createdAt: e.created_at.toISOString(),
        subject: label(e.subject_user_id),
        recordedBy: label(e.actor_user_id) as string,
        status: e.status,
        hash: e.hash,
      }));

      await tx.query(
        'INSERT INTO dispute_access_log (dispute_id, officer_id) VALUES ($1, $2)',
        [d.id, officerId],
      );
      await tx.query(
        'UPDATE disputes SET officer_id = COALESCE(officer_id, $2) WHERE id = $1',
        [d.id, officerId],
      );
      const affected = await this.neededConsent(tx, d.circle_id, d.entry_ids);
      await this.notifications.notify(
        tx,
        affected.map((userId) => ({
          userId,
          kind: 'evidence_viewed' as const,
          circleId: d.circle_id,
          payload: { disputeId: d.id },
        })),
      );
      return {
        dispute: {
          id: d.id,
          circleCode: d.public_code,
          category: d.category,
          status: d.status,
          entryCount: d.entry_ids.length,
          createdAt: d.created_at.toISOString(),
        },
        entries: out,
      };
    });
  }

  resolve(disputeId: string, note: string): Promise<void> {
    return withTransaction(this.pool, async (tx) => {
      const { rows } = await tx.query<DisputeRow>(
        `UPDATE disputes SET status = 'resolved', resolved_at = now(), resolution_note = $2
         WHERE id = $1 AND status = 'consented' RETURNING *`,
        [disputeId, note],
      );
      const d = rows[0];
      if (!d) throw notFound();
      const affected = await this.neededConsent(tx, d.circle_id, d.entry_ids);
      await this.notifications.notify(
        tx,
        affected.map((userId) => ({
          userId,
          kind: 'dispute_updated' as const,
          circleId: d.circle_id,
          payload: { disputeId: d.id, status: 'resolved' },
        })),
      );
    });
  }

  // ---------- helpers ----------

  /** The organizer and everyone the named entries are about. */
  private async neededConsent(
    db: Pool | PoolClient,
    circleId: string,
    entryIds: string[],
  ): Promise<string[]> {
    const { rows } = await db.query<{ user_id: string }>(
      `SELECT user_id FROM circle_members
         WHERE circle_id = $1 AND role = 'organizer' AND left_cycle IS NULL
       UNION
       SELECT e.subject_user_id FROM ledger_entries e
         WHERE e.circle_id = $1 AND e.id = ANY($2::uuid[]) AND e.subject_user_id IS NOT NULL
       UNION
       SELECT d.raised_by FROM disputes d
         WHERE d.circle_id = $1 AND d.entry_ids = $2::uuid[]`,
      [circleId, entryIds],
    );
    return rows.map((r) => r.user_id);
  }

  private async grant(
    tx: PoolClient,
    circleId: string,
    userId: string,
    disputeId: string,
  ): Promise<void> {
    await tx.query(
      `INSERT INTO consents (circle_id, user_id, scope, dispute_id)
       VALUES ($1, $2, 'dispute_evidence', $3) ON CONFLICT DO NOTHING`,
      [circleId, userId, disputeId],
    );
  }

  /** Moves to `consented` once nobody is left to ask. */
  private async settle(
    tx: PoolClient,
    disputeId: string,
    circleId: string,
    entryIds: string[],
  ): Promise<void> {
    const needed = await this.neededConsent(tx, circleId, entryIds);
    const { rows } = await tx.query<{ user_id: string }>(
      `SELECT user_id FROM consents
       WHERE dispute_id = $1 AND scope = 'dispute_evidence' AND revoked_at IS NULL`,
      [disputeId],
    );
    const granted = new Set(rows.map((r) => r.user_id));
    if (!needed.every((u) => granted.has(u))) return;
    await tx.query(
      `UPDATE disputes SET status = 'consented' WHERE id = $1 AND status = 'awaiting_consent'`,
      [disputeId],
    );
    await this.notifications.notify(
      tx,
      needed.map((userId) => ({
        userId,
        kind: 'dispute_updated' as const,
        circleId,
        payload: { disputeId, status: 'consented' },
      })),
    );
  }

  /** Disputes the caller is part of; organizers see all of their circle's. */
  private async memberDisputes(
    db: Pool | PoolClient,
    m: Membership,
    onlyId?: string,
  ): Promise<MemberDispute[]> {
    const { rows } = await db.query<DisputeRow>(
      `SELECT * FROM disputes WHERE circle_id = $1 AND ($2::uuid IS NULL OR id = $2)
       ORDER BY created_at DESC LIMIT 50`,
      [m.circleId, onlyId ?? null],
    );
    const out: MemberDispute[] = [];
    for (const d of rows) {
      const needed = await this.neededConsent(db, d.circle_id, d.entry_ids);
      if (m.role !== 'organizer' && !needed.includes(m.userId)) continue;
      const granted = await db.query<{ user_id: string }>(
        `SELECT user_id FROM consents
         WHERE dispute_id = $1 AND scope = 'dispute_evidence' AND revoked_at IS NULL`,
        [d.id],
      );
      const grantedIds = granted.rows.map((r) => r.user_id);
      const refs = await db.query<{ id: string; reference: string }>(
        `SELECT id, reference FROM ledger_entries WHERE id = ANY($1::uuid[]) ORDER BY seq`,
        [d.entry_ids],
      );
      const views = await db.query<{ viewed_at: Date }>(
        'SELECT viewed_at FROM dispute_access_log WHERE dispute_id = $1 ORDER BY viewed_at DESC',
        [d.id],
      );
      out.push({
        id: d.id,
        category: d.category,
        status: d.status,
        createdAt: d.created_at.toISOString(),
        raisedByYou: d.raised_by === m.userId,
        entries: refs.rows.map((r) => ({
          entryId: r.id,
          reference: r.reference,
        })),
        consent: {
          needed: needed.length,
          granted: needed.filter((u) => grantedIds.includes(u)).length,
          mine: needed.includes(m.userId)
            ? grantedIds.includes(m.userId)
            : null,
        },
        resolutionNote: d.resolution_note,
        views: views.rows.map((v) => v.viewed_at.toISOString()),
      });
    }
    return out;
  }
}
