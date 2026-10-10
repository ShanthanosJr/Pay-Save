import { Inject, Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { Pool } from 'pg';
import type { Membership } from '../circles/circle-role.guard';
import { CIRCLE_TIME_ZONE, localDate } from '../circles/domain/schedule';
import { CLOCK } from '../common/clock/clock';
import type { Clock } from '../common/clock/clock';
import { CryptoService } from '../common/crypto/crypto.service';
import { AppException } from '../common/errors/app.exception';
import { PG_POOL } from '../database/database.module';
import { toInt } from '../database/transaction';
import { EMAIL_TRANSPORT, SMS_TRANSPORT } from '../messaging/messaging.types';
import type {
  EmailTransport,
  SmsTransport,
} from '../messaging/messaging.types';
import { NotificationsService } from '../notifications/notifications.service';
import type { NotificationKind } from '../notifications/notifications.service';
import type { Language } from '../users/users.repository';
import { formatLkr, reminderText } from './reminder-templates';

export const REMINDER_CHANNELS = ['sms', 'email'] as const;
export type ReminderChannel = (typeof REMINDER_CHANNELS)[number];

export interface ReminderPreferences {
  /** Off until the member turns it on (U-06). */
  enabled: boolean;
  daysBefore: number[];
  channels: ReminderChannel[];
  /** Offered in the app, never pre-selected. */
  suggestedDaysBefore: number[];
  emailVerified: boolean;
}

const MARKER_OVERDUE = -1;
const MARKER_NUDGE = -2;

interface Target {
  cycle_id: string;
  user_id: string;
  cycle_number: number;
  due_date: string;
  days_left: number;
  circle_id: string;
  circle_name: string;
  contribution_minor: string;
  channels: ReminderChannel[];
  language: Language;
  email: string | null;
  email_verified_at: Date | null;
  phone_encrypted: Buffer;
}

const TARGET_COLUMNS = `s.cycle_id, s.user_id, s.cycle_number, cy.due_date::text AS due_date,
  (cy.due_date - $1::date) AS days_left, c.id AS circle_id, c.name AS circle_name,
  c.contribution_minor, COALESCE(p.channels, '{}') AS channels, u.language, u.email,
  u.email_verified_at, u.phone_encrypted`;

/** Unpaid members of each active circle's current cycle. */
const TARGET_FROM = `FROM v_cycle_member_status s
  JOIN cycles cy ON cy.id = s.cycle_id AND cy.status = 'open'
  JOIN circles c ON c.id = s.circle_id AND c.status = 'active'
  JOIN users u ON u.id = s.user_id
  LEFT JOIN reminder_preferences p ON p.circle_id = s.circle_id AND p.user_id = s.user_id
  WHERE s.status IN ('due', 'overdue')
    AND NOT EXISTS (SELECT 1 FROM cycles o WHERE o.circle_id = cy.circle_id
                      AND o.status = 'open' AND o.number < cy.number)`;

@Injectable()
export class RemindersService {
  private readonly logger = new Logger('Reminders');

  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    @Inject(CLOCK) private readonly clock: Clock,
    @Inject(SMS_TRANSPORT) private readonly sms: SmsTransport,
    @Inject(EMAIL_TRANSPORT) private readonly email: EmailTransport,
    private readonly crypto: CryptoService,
    private readonly notifications: NotificationsService,
  ) {}

  async get(m: Membership): Promise<ReminderPreferences> {
    const { rows } = await this.pool.query<{
      enabled: boolean | null;
      days_before: number[] | null;
      channels: ReminderChannel[] | null;
      email_verified: boolean;
    }>(
      `SELECT p.enabled, p.days_before, p.channels, (u.email_verified_at IS NOT NULL) AS email_verified
       FROM users u
       LEFT JOIN reminder_preferences p ON p.user_id = u.id AND p.circle_id = $1
       WHERE u.id = $2`,
      [m.circleId, m.userId],
    );
    const r = rows[0];
    return {
      enabled: r?.enabled ?? false,
      daysBefore: r?.days_before ?? [],
      channels: r?.channels ?? [],
      suggestedDaysBefore: [3],
      emailVerified: r?.email_verified ?? false,
    };
  }

  async set(
    m: Membership,
    input: {
      enabled: boolean;
      daysBefore: number[];
      channels: ReminderChannel[];
    },
  ): Promise<ReminderPreferences> {
    const days = [...new Set(input.daysBefore)].sort((a, b) => b - a);
    const channels = [...new Set(input.channels)];
    if (input.enabled && days.length === 0)
      throw new AppException(
        400,
        'REMINDER_DAYS_REQUIRED',
        'Choose when to be reminded',
      );
    const current = await this.get(m);
    if (channels.includes('email') && !current.emailVerified)
      throw new AppException(
        409,
        'EMAIL_NOT_VERIFIED',
        'Verify your email before using email reminders',
      );
    await this.pool.query(
      `INSERT INTO reminder_preferences (circle_id, user_id, enabled, days_before, channels)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (circle_id, user_id) DO UPDATE
         SET enabled = $3, days_before = $4, channels = $5, updated_at = now()`,
      [m.circleId, m.userId, input.enabled, days, channels],
    );
    return this.get(m);
  }

  /** Organizer's "Send reminder" for one unpaid member; at most once a day. */
  async nudge(m: Membership, userId: string): Promise<{ sent: boolean }> {
    const today = localDate(this.clock.now());
    const { rows } = await this.pool.query<Target>(
      `SELECT ${TARGET_COLUMNS} ${TARGET_FROM} AND s.circle_id = $2 AND s.user_id = $3`,
      [today, m.circleId, userId.toLowerCase()],
    );
    const t = rows[0];
    if (!t || t.user_id === m.userId)
      throw new AppException(
        409,
        'NOT_UNPAID',
        'This member has nothing unpaid in the current cycle',
      );
    if (!(await this.claim(t, MARKER_NUDGE, today)))
      throw new AppException(
        429,
        'ALREADY_REMINDED',
        'You already reminded this member today',
      );
    await this.deliver(t, 'organizer_nudge');
    return { sent: true };
  }

  @Cron('5 * * * *')
  async tick(): Promise<void> {
    const now = this.clock.now();
    const hour = Number(
      new Intl.DateTimeFormat('en-GB', {
        timeZone: CIRCLE_TIME_ZONE,
        hour: '2-digit',
        hourCycle: 'h23',
      }).format(now),
    );
    // nobody wants a seettu reminder at 3 a.m.
    if (hour < 8 || hour >= 20) return;
    try {
      const sent = await this.run(now);
      if (sent > 0) this.logger.log(`sent ${sent} reminder(s)`);
    } catch (err) {
      this.logger.error((err as Error).message);
    }
  }

  /** Sends every reminder that is due and not yet sent. Safe to re-run. */
  async run(now: Date): Promise<number> {
    const today = localDate(now);
    const { rows } = await this.pool.query<Target>(
      `SELECT ${TARGET_COLUMNS} ${TARGET_FROM} AND p.enabled
         AND ((cy.due_date - $1::date) = ANY(p.days_before) OR cy.due_date < $1::date)`,
      [today],
    );
    let sent = 0;
    for (const t of rows) {
      const overdue = t.days_left < 0;
      const claimed = overdue
        ? await this.claim(t, MARKER_OVERDUE, t.due_date)
        : await this.claim(t, t.days_left, today);
      if (!claimed) continue;
      await this.deliver(t, overdue ? 'reminder_overdue' : 'reminder_due');
      sent++;
    }
    return sent;
  }

  private async claim(t: Target, marker: number, on: string): Promise<boolean> {
    const { rowCount } = await this.pool.query(
      `INSERT INTO reminder_deliveries (cycle_id, user_id, marker, sent_on)
       VALUES ($1, $2, $3, $4) ON CONFLICT DO NOTHING`,
      [t.cycle_id, t.user_id, marker, on],
    );
    return rowCount === 1;
  }

  private async deliver(t: Target, kind: NotificationKind): Promise<void> {
    const amountMinor = toInt(t.contribution_minor);
    await this.notifications.notify(this.pool, [
      {
        userId: t.user_id,
        kind,
        circleId: t.circle_id,
        payload: {
          cycleNumber: t.cycle_number,
          dueDate: t.due_date,
          daysLeft: t.days_left,
          amountMinor,
        },
      },
    ]);
    const { subject, text } = reminderText(t.language, {
      circle: t.circle_name,
      cycle: t.cycle_number,
      amount: formatLkr(amountMinor),
      dueDate: t.due_date,
      daysLeft: t.days_left,
    });
    // A gateway outage must not lose the in-app reminder or stop the batch.
    try {
      if (t.channels.includes('sms'))
        await this.sms.send({
          to: this.crypto.decryptPii(t.phone_encrypted, 'phone'),
          text,
        });
      if (t.channels.includes('email') && t.email && t.email_verified_at)
        await this.email.send({ to: t.email, subject, text });
    } catch (err) {
      this.logger.warn((err as Error).message);
    }
  }
}
