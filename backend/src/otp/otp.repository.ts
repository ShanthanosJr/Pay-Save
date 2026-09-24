import { Inject, Injectable } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { OtpPurpose } from './otp-sender';

export interface OtpChallenge {
  id: string;
  purpose: OtpPurpose;
  targetHash: string;
  userId: string | null;
  codeHash: string;
  expiresAt: Date;
  attempts: number;
  consumedAt: Date | null;
  createdAt: Date;
}

export interface NewOtpChallenge {
  purpose: OtpPurpose;
  targetHash: string;
  userId: string | null;
  codeHash: string;
  expiresAt: Date;
  createdAt: Date;
}

interface Row {
  id: string;
  purpose: OtpPurpose;
  target_hash: string;
  user_id: string | null;
  code_hash: string;
  expires_at: Date;
  attempts: number;
  consumed_at: Date | null;
  created_at: Date;
}

const COLUMNS =
  'id, purpose, target_hash, user_id, code_hash, expires_at, attempts, consumed_at, created_at';

const toChallenge = (r: Row): OtpChallenge => ({
  id: r.id,
  purpose: r.purpose,
  targetHash: r.target_hash,
  userId: r.user_id,
  codeHash: r.code_hash,
  expiresAt: r.expires_at,
  attempts: r.attempts,
  consumedAt: r.consumed_at,
  createdAt: r.created_at,
});

@Injectable()
export class OtpRepository {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async findLatest(
    purpose: OtpPurpose,
    targetHash: string,
  ): Promise<OtpChallenge | null> {
    const { rows } = await this.pool.query<Row>(
      `SELECT ${COLUMNS} FROM otp_challenges
       WHERE purpose = $1 AND target_hash = $2
       ORDER BY created_at DESC LIMIT 1`,
      [purpose, targetHash],
    );
    return rows[0] ? toChallenge(rows[0]) : null;
  }

  async invalidateActive(
    purpose: OtpPurpose,
    targetHash: string,
    at: Date,
  ): Promise<void> {
    await this.pool.query(
      `UPDATE otp_challenges SET consumed_at = $3
       WHERE purpose = $1 AND target_hash = $2 AND consumed_at IS NULL`,
      [purpose, targetHash, at],
    );
  }

  async insert(c: NewOtpChallenge): Promise<OtpChallenge> {
    const { rows } = await this.pool.query<Row>(
      `INSERT INTO otp_challenges (purpose, target_hash, user_id, code_hash, expires_at, created_at)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING ${COLUMNS}`,
      [c.purpose, c.targetHash, c.userId, c.codeHash, c.expiresAt, c.createdAt],
    );
    return toChallenge(rows[0]);
  }

  async incrementAttempts(id: string): Promise<number> {
    const { rows } = await this.pool.query<{ attempts: number }>(
      'UPDATE otp_challenges SET attempts = attempts + 1 WHERE id = $1 RETURNING attempts',
      [id],
    );
    return rows[0]?.attempts ?? Number.MAX_SAFE_INTEGER;
  }

  async consume(id: string, at: Date): Promise<boolean> {
    const { rowCount } = await this.pool.query(
      'UPDATE otp_challenges SET consumed_at = $2 WHERE id = $1 AND consumed_at IS NULL',
      [id, at],
    );
    return rowCount === 1;
  }
}
