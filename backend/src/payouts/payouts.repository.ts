import { Inject, Injectable } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { Db } from '../database/transaction';
import type { PayoutKind } from './payout-details';

export interface MethodRow {
  id: string;
  user_id: string;
  kind: PayoutKind;
  summary: string;
  details_encrypted: Buffer;
  is_default: boolean;
  created_at: Date;
}

export interface ShareRow extends MethodRow {
  preferred: boolean;
}

const COLS =
  'm.id, m.user_id, m.kind, m.summary, m.details_encrypted, m.is_default, m.created_at';

@Injectable()
export class PayoutsRepository {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async listMine(db: Db, userId: string): Promise<MethodRow[]> {
    const { rows } = await db.query<MethodRow>(
      `SELECT ${COLS} FROM payout_methods m
       WHERE m.user_id = $1 AND m.archived_at IS NULL
       ORDER BY m.is_default DESC, m.created_at`,
      [userId],
    );
    return rows;
  }

  async countMine(db: Db, userId: string): Promise<number> {
    const { rows } = await db.query<{ n: number }>(
      'SELECT count(*)::int AS n FROM payout_methods WHERE user_id = $1 AND archived_at IS NULL',
      [userId],
    );
    return rows[0].n;
  }

  async insert(
    db: Db,
    m: { userId: string; kind: PayoutKind; summary: string; details: Buffer },
  ): Promise<string> {
    const { rows } = await db.query<{ id: string }>(
      `INSERT INTO payout_methods (user_id, kind, summary, details_encrypted)
       VALUES ($1, $2, $3, $4) RETURNING id`,
      [m.userId, m.kind, m.summary, m.details],
    );
    return rows[0].id;
  }

  async setDefault(db: Db, userId: string, methodId: string): Promise<boolean> {
    await db.query(
      'UPDATE payout_methods SET is_default = false WHERE user_id = $1 AND is_default',
      [userId],
    );
    const { rowCount } = await db.query(
      `UPDATE payout_methods SET is_default = true
       WHERE id = $2 AND user_id = $1 AND archived_at IS NULL`,
      [userId, methodId],
    );
    return rowCount === 1;
  }

  /**
   * Circles (not yet completed) where this method is the member's only
   * shared one; archiving it would leave payers with no way to pay them.
   */
  async circlesRelyingOn(
    db: Db,
    userId: string,
    methodId: string,
  ): Promise<string[]> {
    const { rows } = await db.query<{ name: string }>(
      `SELECT c.name FROM circle_payout_shares s
       JOIN circles c ON c.id = s.circle_id
       WHERE s.method_id = $2 AND s.user_id = $1 AND c.status <> 'completed'
         AND NOT EXISTS (SELECT 1 FROM circle_payout_shares o
                         WHERE o.circle_id = s.circle_id AND o.user_id = $1 AND o.method_id <> $2)`,
      [userId, methodId],
    );
    return rows.map((r) => r.name);
  }

  async archive(db: Db, userId: string, methodId: string): Promise<boolean> {
    const { rowCount } = await db.query(
      `UPDATE payout_methods SET archived_at = now(), is_default = false
       WHERE id = $2 AND user_id = $1 AND archived_at IS NULL`,
      [userId, methodId],
    );
    await db.query(
      'DELETE FROM circle_payout_shares WHERE method_id = $2 AND user_id = $1',
      [userId, methodId],
    );
    return rowCount === 1;
  }

  /** Replaces a member's shares for one circle. */
  async replaceShares(
    db: Db,
    circleId: string,
    userId: string,
    methodIds: string[],
    preferredId: string,
  ): Promise<void> {
    await db.query(
      'DELETE FROM circle_payout_shares WHERE circle_id = $1 AND user_id = $2',
      [circleId, userId],
    );
    await db.query(
      `INSERT INTO circle_payout_shares (circle_id, user_id, method_id, preferred)
       SELECT $1, $2, id, id = $4 FROM payout_methods
       WHERE id = ANY($3::uuid[]) AND user_id = $2 AND archived_at IS NULL`,
      [circleId, userId, methodIds, preferredId],
    );
  }

  async ownsActive(db: Db, userId: string, ids: string[]): Promise<boolean> {
    const { rows } = await db.query<{ n: number }>(
      `SELECT count(*)::int AS n FROM payout_methods
       WHERE id = ANY($2::uuid[]) AND user_id = $1 AND archived_at IS NULL`,
      [userId, ids],
    );
    return rows[0].n === new Set(ids).size;
  }

  async defaultMethodId(db: Db, userId: string): Promise<string | null> {
    const { rows } = await db.query<{ id: string }>(
      `SELECT id FROM payout_methods
       WHERE user_id = $1 AND is_default AND archived_at IS NULL`,
      [userId],
    );
    return rows[0]?.id ?? null;
  }

  async shares(db: Db, circleId: string, userId: string): Promise<ShareRow[]> {
    const { rows } = await db.query<ShareRow>(
      `SELECT ${COLS}, s.preferred FROM circle_payout_shares s
       JOIN payout_methods m ON m.id = s.method_id
       WHERE s.circle_id = $1 AND s.user_id = $2 AND m.archived_at IS NULL
       ORDER BY s.preferred DESC, m.created_at`,
      [circleId, userId],
    );
    return rows;
  }

  /** Shared kinds per member of a circle, for readiness (no details). */
  async kindsByMember(
    db: Db,
    circleId: string,
  ): Promise<Map<string, PayoutKind[]>> {
    const { rows } = await db.query<{ user_id: string; kinds: PayoutKind[] }>(
      `SELECT s.user_id, array_agg(m.kind ORDER BY s.preferred DESC, m.created_at) AS kinds
       FROM circle_payout_shares s JOIN payout_methods m ON m.id = s.method_id
       WHERE s.circle_id = $1 AND m.archived_at IS NULL
       GROUP BY s.user_id`,
      [circleId],
    );
    return new Map(rows.map((r) => [r.user_id, r.kinds]));
  }

  async logAccess(
    db: Db,
    a: {
      circleId: string;
      viewerId: string;
      ownerId: string;
      cycleId: string | null;
    },
  ): Promise<void> {
    await db.query(
      `INSERT INTO payout_detail_access_log (circle_id, viewer_id, owner_id, cycle_id)
       VALUES ($1, $2, $3, $4)`,
      [a.circleId, a.viewerId, a.ownerId, a.cycleId],
    );
  }
}
