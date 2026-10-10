import { Inject, Injectable } from '@nestjs/common';
import { randomInt } from 'node:crypto';
import { Pool } from 'pg';
import type { Membership } from '../circles/circle-role.guard';
import { CirclesService } from '../circles/circles.service';
import type { Total } from '../circles/circles.types';
import { AppException } from '../common/errors/app.exception';
import { APP_CONFIG } from '../config/app-config';
import type { AppConfig } from '../config/app-config';
import { PG_POOL } from '../database/database.module';
import { toInt, withTransaction } from '../database/transaction';
import type { PaymentMethod } from '../ledger/ledger.types';

export interface StatementLine {
  entryId: string;
  reference: string;
  cycleNumber: number;
  amountMinor: number;
  method: PaymentMethod | null;
  recordedAt: string;
  verifiedAt: string;
}

export interface Statement {
  id: string;
  verificationCode: string;
  verifyUrl: string;
  issuedAt: string;
  holderName: string;
  circle: { name: string; publicCode: string };
  /** Verified contributions only, with the arithmetic (NFR-07). */
  contributions: Total;
  lines: StatementLine[];
  payoutsReceived: {
    cycleNumber: number;
    amountMinor: number;
    reference: string;
  }[];
  chainHeadHash: string;
}

export interface PublicVerification {
  valid: boolean;
  /** False when any ledger entry up to the statement was altered since. */
  ledgerIntact?: boolean;
  issuedAt?: string;
  holderInitials?: string;
  circleCode?: string;
  contributions?: Omit<Total, 'entryIds'>;
  chainHeadHash?: string;
}

interface Row {
  id: string;
  verification_code: string;
  issued_at: Date;
  holder_name: string;
  circle_id: string;
  circle_name: string;
  public_code: string;
  verified_count: number;
  unit_minor: string;
  total_minor: string;
  chain_head_hash: string;
  head_seq: string;
  payload: {
    lines: StatementLine[];
    payoutsReceived: Statement['payoutsReceived'];
  };
}

const SELECT = `SELECT s.id, s.verification_code, s.issued_at, s.holder_name, s.circle_id,
    c.name AS circle_name, c.public_code, s.verified_count, s.unit_minor, s.total_minor,
    s.chain_head_hash, s.head_seq, s.payload
  FROM statements s JOIN circles c ON c.id = s.circle_id`;

// no 0/O/1/I, so a code read aloud or copied by hand survives
const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

export function newVerificationCode(): string {
  const group = () =>
    Array.from({ length: 4 }, () => ALPHABET[randomInt(ALPHABET.length)]).join(
      '',
    );
  return `PS-${group()}-${group()}-${group()}`;
}

export const normalizeVerificationCode = (raw: string): string =>
  raw
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, '')
    .replace(/^PS/, '');

const initials = (name: string): string =>
  name
    .trim()
    .split(/\s+/)
    .map((p) => `${[...p][0]?.toUpperCase() ?? ''}.`)
    .join(' ');

@Injectable()
export class StatementsService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    @Inject(APP_CONFIG) private readonly cfg: AppConfig,
    private readonly circles: CirclesService,
  ) {}

  /** Snapshots the member's verified savings and pins it to the ledger's head. */
  issue(m: Membership): Promise<Statement> {
    return withTransaction(this.pool, async (tx) => {
      const circle = await this.circles.lock(tx, m.circleId);
      const broken = await tx.query<{ seq: string | null }>(
        'SELECT ledger_chain_break($1) AS seq',
        [circle.id],
      );
      if (broken.rows[0].seq !== null)
        throw new AppException(
          409,
          'LEDGER_INTEGRITY',
          'This circle’s record failed its integrity check',
        );
      const head = await tx.query<{ seq: string; hash: string }>(
        `SELECT seq, hash FROM ledger_entries WHERE circle_id = $1 ORDER BY seq DESC LIMIT 1`,
        [circle.id],
      );
      const lines = await tx.query<{
        id: string;
        reference: string;
        cycle_number: number;
        amount_minor: string;
        method: PaymentMethod | null;
        recorded_at: Date;
        verified_at: Date;
      }>(
        `SELECT e.id, e.reference, s.cycle_number, s.amount_minor, e.method, s.recorded_at, s.verified_at
         FROM v_cycle_member_status s JOIN ledger_entries e ON e.id = s.contribution_id
         WHERE s.circle_id = $1 AND s.user_id = $2 AND s.status = 'verified'
         ORDER BY s.cycle_number`,
        [circle.id, m.userId],
      );
      if (lines.rows.length === 0)
        throw new AppException(
          409,
          'NOTHING_VERIFIED',
          'You have no verified payments in this circle yet',
        );
      const payouts = await tx.query<{
        cycle_number: number;
        amount_minor: string;
        reference: string;
      }>(
        `SELECT cy.number AS cycle_number, e.amount_minor, e.reference
         FROM ledger_entries e JOIN cycles cy ON cy.id = e.cycle_id
         WHERE e.circle_id = $1 AND e.subject_user_id = $2 AND e.entry_type = 'payout'
           AND e.amount_minor IS NOT NULL
         ORDER BY cy.number`,
        [circle.id, m.userId],
      );
      const holder = await tx.query<{ name: string }>(
        'SELECT COALESCE(full_name, display_name) AS name FROM users WHERE id = $1',
        [m.userId],
      );
      const payload = {
        lines: lines.rows.map((r) => ({
          entryId: r.id,
          reference: r.reference,
          cycleNumber: r.cycle_number,
          amountMinor: toInt(r.amount_minor),
          method: r.method,
          recordedAt: r.recorded_at.toISOString(),
          verifiedAt: r.verified_at.toISOString(),
        })),
        payoutsReceived: payouts.rows.map((r) => ({
          cycleNumber: r.cycle_number,
          amountMinor: toInt(r.amount_minor),
          reference: r.reference,
        })),
      };
      const total = payload.lines.reduce((sum, l) => sum + l.amountMinor, 0);
      const { rows } = await tx.query<{ id: string }>(
        `INSERT INTO statements (user_id, circle_id, verification_code, chain_head_hash, head_seq,
                                 verified_count, unit_minor, total_minor, holder_name, payload)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10::jsonb) RETURNING id`,
        [
          m.userId,
          circle.id,
          newVerificationCode(),
          head.rows[0].hash,
          head.rows[0].seq,
          payload.lines.length,
          circle.contributionMinor,
          total,
          holder.rows[0].name,
          JSON.stringify(payload),
        ],
      );
      const created = await tx.query<Row>(`${SELECT} WHERE s.id = $1`, [
        rows[0].id,
      ]);
      return this.toStatement(created.rows[0]);
    });
  }

  async list(m: Membership): Promise<{ statements: Statement[] }> {
    const { rows } = await this.pool.query<Row>(
      `${SELECT} WHERE s.circle_id = $1 AND s.user_id = $2 ORDER BY s.issued_at DESC LIMIT 20`,
      [m.circleId, m.userId],
    );
    return { statements: rows.map((r) => this.toStatement(r)) };
  }

  /** Only the member the statement is about can fetch it. */
  async mine(userId: string, id: string): Promise<Statement> {
    const { rows } = await this.pool.query<Row>(
      `${SELECT} WHERE s.id = $1 AND s.user_id = $2`,
      [id, userId],
    );
    if (!rows[0])
      throw new AppException(404, 'NOT_FOUND', 'Statement not found');
    return this.toStatement(rows[0]);
  }

  /**
   * What a bank officer sees: is the code genuine, and does the ledger it
   * was issued from still verify. Nothing beyond the printed totals.
   */
  async verify(rawCode: string): Promise<PublicVerification> {
    const key = normalizeVerificationCode(rawCode);
    if (key.length !== 12) return { valid: false };
    const code = `PS-${key.slice(0, 4)}-${key.slice(4, 8)}-${key.slice(8)}`;
    const { rows } = await this.pool.query<Row & { intact: boolean }>(
      `${SELECT.replace(
        's.payload',
        `s.payload, (ledger_chain_break(s.circle_id, s.head_seq) IS NULL AND EXISTS (
           SELECT 1 FROM ledger_entries h WHERE h.circle_id = s.circle_id
             AND h.seq = s.head_seq AND h.hash = s.chain_head_hash)) AS intact`,
      )} WHERE s.verification_code = $1`,
      [code],
    );
    const r = rows[0];
    if (!r) return { valid: false };
    return {
      valid: true,
      ledgerIntact: r.intact,
      issuedAt: r.issued_at.toISOString(),
      holderInitials: initials(r.holder_name),
      circleCode: r.public_code,
      contributions: {
        count: r.verified_count,
        unitMinor: toInt(r.unit_minor),
        totalMinor: toInt(r.total_minor),
      },
      chainHeadHash: r.chain_head_hash,
    };
  }

  private toStatement(r: Row): Statement {
    return {
      id: r.id,
      verificationCode: r.verification_code,
      verifyUrl: `${this.cfg.publicBaseUrl}/verify/${r.verification_code}`,
      issuedAt: r.issued_at.toISOString(),
      holderName: r.holder_name,
      circle: { name: r.circle_name, publicCode: r.public_code },
      contributions: {
        count: r.verified_count,
        unitMinor: toInt(r.unit_minor),
        totalMinor: toInt(r.total_minor),
        entryIds: r.payload.lines.map((l) => l.entryId),
      },
      lines: r.payload.lines,
      payoutsReceived: r.payload.payoutsReceived,
      chainHeadHash: r.chain_head_hash,
    };
  }
}
