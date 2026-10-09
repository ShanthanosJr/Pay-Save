import { Injectable } from '@nestjs/common';
import { PoolClient } from 'pg';
import { Db } from '../database/transaction';

export type InvitationStatus =
  'pending' | 'accepted' | 'declined' | 'cancelled';

export interface InvitationRow {
  id: string;
  circle_id: string;
  invitee_id: string;
  invited_by: string;
  status: InvitationStatus;
  message: string | null;
  created_at: Date;
}

export interface PersonLite {
  id: string;
  name: string;
  username: string | null;
  avatar_updated_at: Date | null;
}

export interface InvitablePalRow extends PersonLite {
  in_circle: boolean;
  invitation_id: string | null;
}

export interface PendingRow extends PersonLite {
  invitation_id: string;
  created_at: Date;
}

/** Invitations for `user_id`, with what they need to decide. */
export interface MyInvitationRow extends InvitationRow {
  organizer_id: string;
  organizer_name: string;
  organizer_username: string | null;
  organizer_avatar_updated_at: Date | null;
  member_count: number;
  pending_count: number;
  pal_names: string[] | null;
}

const PAIR = `user_low = LEAST($1::uuid, $2::uuid) AND user_high = GREATEST($1::uuid, $2::uuid)`;

@Injectable()
export class CircleInvitationsRepository {
  async arePals(db: Db, a: string, b: string): Promise<boolean> {
    const { rows } = await db.query(`SELECT 1 FROM pals WHERE ${PAIR}`, [a, b]);
    return rows.length > 0;
  }

  /** Of `ids`, the ones that are not pals of `organizerId`. */
  async notPals(db: Db, organizerId: string, ids: string[]): Promise<string[]> {
    const { rows } = await db.query<{ id: string }>(
      `SELECT x.id FROM unnest($2::uuid[]) AS x(id)
       WHERE NOT EXISTS (SELECT 1 FROM pals p
         WHERE p.user_low = LEAST($1::uuid, x.id) AND p.user_high = GREATEST($1::uuid, x.id))`,
      [organizerId, ids],
    );
    return rows.map((r) => r.id);
  }

  /** The organizer's pals, flagged if already in the circle or invited. */
  async invitablePals(
    db: Db,
    circleId: string,
    organizerId: string,
  ): Promise<InvitablePalRow[]> {
    const { rows } = await db.query<InvitablePalRow>(
      `SELECT u.id, COALESCE(u.full_name, u.display_name) AS name, u.username, u.avatar_updated_at,
              EXISTS (SELECT 1 FROM circle_members m
                      WHERE m.circle_id = $1 AND m.user_id = u.id AND m.left_cycle IS NULL) AS in_circle,
              (SELECT i.id FROM circle_invitations i
               WHERE i.circle_id = $1 AND i.invitee_id = u.id AND i.status = 'pending') AS invitation_id
       FROM pals p
       JOIN users u ON u.id = CASE WHEN p.user_low = $2 THEN p.user_high ELSE p.user_low END
       WHERE (p.user_low = $2 OR p.user_high = $2)
       ORDER BY name`,
      [circleId, organizerId],
    );
    return rows;
  }

  async pendingForCircle(db: Db, circleId: string): Promise<PendingRow[]> {
    const { rows } = await db.query<PendingRow>(
      `SELECT i.id AS invitation_id, i.created_at, u.id, COALESCE(u.full_name, u.display_name) AS name,
              u.username, u.avatar_updated_at
       FROM circle_invitations i JOIN users u ON u.id = i.invitee_id
       WHERE i.circle_id = $1 AND i.status = 'pending'
       ORDER BY i.created_at`,
      [circleId],
    );
    return rows;
  }

  async pendingCount(db: Db, circleId: string): Promise<number> {
    const { rows } = await db.query<{ n: number }>(
      `SELECT count(*)::int AS n FROM circle_invitations WHERE circle_id = $1 AND status = 'pending'`,
      [circleId],
    );
    return rows[0].n;
  }

  /** Inserts pending invitations; ones already pending are left as they are. */
  async insertMany(
    tx: PoolClient,
    circleId: string,
    invitedBy: string,
    ids: string[],
    message: string | null,
  ): Promise<number> {
    const { rowCount } = await tx.query(
      `INSERT INTO circle_invitations (circle_id, invitee_id, invited_by, message)
       SELECT $1, x.id, $2, $4 FROM unnest($3::uuid[]) AS x(id)
       ON CONFLICT (circle_id, invitee_id) WHERE status = 'pending' DO NOTHING`,
      [circleId, invitedBy, ids, message],
    );
    return rowCount ?? 0;
  }

  async lockById(tx: PoolClient, id: string): Promise<InvitationRow | null> {
    const { rows } = await tx.query<InvitationRow>(
      'SELECT * FROM circle_invitations WHERE id = $1 FOR UPDATE',
      [id],
    );
    return rows[0] ?? null;
  }

  async setStatus(
    db: Db,
    id: string,
    status: InvitationStatus,
    at: Date,
  ): Promise<void> {
    await db.query(
      'UPDATE circle_invitations SET status = $2, responded_at = $3 WHERE id = $1',
      [id, status, at],
    );
  }

  async cancelPending(db: Db, circleId: string, at: Date): Promise<void> {
    await db.query(
      `UPDATE circle_invitations SET status = 'cancelled', responded_at = $2
       WHERE circle_id = $1 AND status = 'pending'`,
      [circleId, at],
    );
  }

  async mine(db: Db, userId: string): Promise<MyInvitationRow[]> {
    const { rows } = await db.query<MyInvitationRow>(
      `SELECT i.*,
              o.id AS organizer_id, COALESCE(o.full_name, o.display_name) AS organizer_name,
              o.username AS organizer_username, o.avatar_updated_at AS organizer_avatar_updated_at,
              (SELECT count(*)::int FROM circle_members m
               WHERE m.circle_id = i.circle_id AND m.left_cycle IS NULL) AS member_count,
              (SELECT count(*)::int FROM circle_invitations x
               WHERE x.circle_id = i.circle_id AND x.status = 'pending') AS pending_count,
              -- members who are also my pals: "Nimal and 2 others you know"
              (SELECT array_agg(COALESCE(u.full_name, u.display_name) ORDER BY u.display_name)
               FROM circle_members m JOIN users u ON u.id = m.user_id
               JOIN pals p ON p.user_low = LEAST($1::uuid, m.user_id) AND p.user_high = GREATEST($1::uuid, m.user_id)
               WHERE m.circle_id = i.circle_id AND m.left_cycle IS NULL) AS pal_names
       FROM circle_invitations i
       JOIN circle_members om ON om.circle_id = i.circle_id AND om.role = 'organizer'
       JOIN users o ON o.id = om.user_id
       WHERE i.invitee_id = $1 AND i.status = 'pending'
       ORDER BY i.created_at DESC`,
      [userId],
    );
    return rows;
  }
}
