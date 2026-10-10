import { Inject, Injectable } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { Db } from '../database/transaction';

/** Rendered by the app in the reader's language from `kind` + `payload`. */
export type NotificationKind =
  | 'payment_recorded'
  | 'payment_recorded_for_you'
  | 'payment_verified'
  | 'payment_rejected'
  | 'cycle_closed'
  | 'payout_due_to_you'
  | 'circle_started'
  | 'circle_invitation'
  | 'member_joined'
  | 'member_removed'
  | 'reminder_due'
  | 'reminder_overdue'
  | 'organizer_nudge'
  | 'dispute_consent_requested'
  | 'dispute_updated'
  | 'evidence_viewed';

export interface NewNotification {
  userId: string;
  kind: NotificationKind;
  circleId?: string | null;
  payload?: Record<string, unknown>;
}

export interface NotificationItem {
  id: string;
  kind: NotificationKind;
  circleId: string | null;
  circleName: string | null;
  payload: Record<string, unknown>;
  createdAt: string;
  read: boolean;
}

@Injectable()
export class NotificationsService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  /** Pass the caller's transaction so a rolled-back action notifies no one. */
  async notify(db: Db, items: NewNotification[]): Promise<void> {
    if (items.length === 0) return;
    await db.query(
      `INSERT INTO notifications (user_id, kind, circle_id, payload)
       SELECT * FROM unnest($1::uuid[], $2::text[], $3::uuid[], $4::jsonb[])`,
      [
        items.map((i) => i.userId),
        items.map((i) => i.kind),
        items.map((i) => i.circleId ?? null),
        items.map((i) => JSON.stringify(i.payload ?? {})),
      ],
    );
  }

  async list(
    userId: string,
    limit: number,
  ): Promise<{ items: NotificationItem[]; unread: number }> {
    const { rows } = await this.pool.query<{
      id: string;
      kind: NotificationKind;
      circle_id: string | null;
      circle_name: string | null;
      payload: Record<string, unknown>;
      created_at: Date;
      read_at: Date | null;
    }>(
      `SELECT n.id, n.kind, n.circle_id, c.name AS circle_name, n.payload, n.created_at, n.read_at
       FROM notifications n LEFT JOIN circles c ON c.id = n.circle_id
       WHERE n.user_id = $1 ORDER BY n.created_at DESC, n.id LIMIT $2`,
      [userId, limit],
    );
    return {
      items: rows.map((r) => ({
        id: r.id,
        kind: r.kind,
        circleId: r.circle_id,
        circleName: r.circle_name,
        payload: r.payload,
        createdAt: r.created_at.toISOString(),
        read: r.read_at !== null,
      })),
      unread: await this.unread(userId),
    };
  }

  async unread(userId: string): Promise<number> {
    const { rows } = await this.pool.query<{ n: number }>(
      `SELECT count(*)::int AS n FROM notifications WHERE user_id = $1 AND read_at IS NULL`,
      [userId],
    );
    return rows[0].n;
  }

  async markRead(userId: string, ids?: string[]): Promise<{ unread: number }> {
    await this.pool.query(
      `UPDATE notifications SET read_at = now()
       WHERE user_id = $1 AND read_at IS NULL AND ($2::uuid[] IS NULL OR id = ANY($2))`,
      [userId, ids?.length ? ids : null],
    );
    return { unread: await this.unread(userId) };
  }
}
