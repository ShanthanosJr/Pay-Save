import { Inject, Injectable } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';

export type Language = 'en' | 'si' | 'ta';

export interface UserRecord {
  id: string;
  fullName: string;
  age: number | null;
  phoneEncrypted: Buffer;
  phoneHash: string;
  nicEncrypted: Buffer | null;
  email: string | null;
  emailVerifiedAt: Date | null;
  phoneVerifiedAt: Date | null;
  passwordHash: string | null;
  refreshTokenHash: string | null;
  failedLoginCount: number;
  lockedUntil: Date | null;
  language: Language;
  createdAt: Date;
}

export interface NewUser {
  fullName: string;
  age: number;
  phoneEncrypted: Buffer;
  phoneHash: string;
  nicEncrypted: Buffer;
  nicHash: string;
  email: string;
  passwordHash: string;
  phoneVerifiedAt: Date;
}

interface Row {
  id: string;
  full_name: string | null;
  display_name: string;
  age: number | null;
  phone_encrypted: Buffer;
  phone_hash: string;
  nic_encrypted: Buffer | null;
  email: string | null;
  email_verified_at: Date | null;
  phone_verified_at: Date | null;
  password_hash: string | null;
  refresh_token_hash: string | null;
  failed_login_count: number;
  locked_until: Date | null;
  language: Language;
  created_at: Date;
}

const COLUMNS = `id, full_name, display_name, age, phone_encrypted, phone_hash, nic_encrypted, email,
  email_verified_at, phone_verified_at, password_hash, refresh_token_hash, failed_login_count,
  locked_until, language, created_at`;

const toUser = (r: Row): UserRecord => ({
  id: r.id,
  fullName: r.full_name ?? r.display_name,
  age: r.age,
  phoneEncrypted: r.phone_encrypted,
  phoneHash: r.phone_hash,
  nicEncrypted: r.nic_encrypted,
  email: r.email,
  emailVerifiedAt: r.email_verified_at,
  phoneVerifiedAt: r.phone_verified_at,
  passwordHash: r.password_hash,
  refreshTokenHash: r.refresh_token_hash,
  failedLoginCount: r.failed_login_count,
  lockedUntil: r.locked_until,
  language: r.language,
  createdAt: r.created_at,
});

@Injectable()
export class UsersRepository {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  private async one(
    sql: string,
    params: unknown[],
  ): Promise<UserRecord | null> {
    const { rows } = await this.pool.query<Row>(sql, params);
    return rows[0] ? toUser(rows[0]) : null;
  }

  findById(id: string): Promise<UserRecord | null> {
    return this.one(`SELECT ${COLUMNS} FROM users WHERE id = $1`, [id]);
  }

  findByEmail(email: string): Promise<UserRecord | null> {
    return this.one(`SELECT ${COLUMNS} FROM users WHERE email = $1`, [email]);
  }

  findByPhoneHash(phoneHash: string): Promise<UserRecord | null> {
    return this.one(`SELECT ${COLUMNS} FROM users WHERE phone_hash = $1`, [
      phoneHash,
    ]);
  }

  async findConflicts(c: {
    phoneHash: string;
    email: string;
    nicHash: string;
  }): Promise<{ phone: boolean; email: boolean; nic: boolean }> {
    const { rows } = await this.pool.query<{
      phone: boolean;
      email: boolean;
      nic: boolean;
    }>(
      `SELECT COALESCE(bool_or(phone_hash = $1), false) AS phone,
              COALESCE(bool_or(email = $2), false) AS email,
              COALESCE(bool_or(nic_hash = $3), false) AS nic
       FROM users WHERE phone_hash = $1 OR email = $2 OR nic_hash = $3`,
      [c.phoneHash, c.email, c.nicHash],
    );
    return rows[0];
  }

  async create(u: NewUser): Promise<UserRecord> {
    const user = await this.one(
      `INSERT INTO users (display_name, full_name, age, phone_encrypted, phone_hash, nic_encrypted, nic_hash,
                          email, password_hash, phone_verified_at)
       VALUES ($1, $1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING ${COLUMNS}`,
      [
        u.fullName,
        u.age,
        u.phoneEncrypted,
        u.phoneHash,
        u.nicEncrypted,
        u.nicHash,
        u.email,
        u.passwordHash,
        u.phoneVerifiedAt,
      ],
    );
    return user as UserRecord;
  }

  async setRefreshHash(userId: string, hash: string | null): Promise<void> {
    await this.pool.query(
      'UPDATE users SET refresh_token_hash = $2, updated_at = now() WHERE id = $1',
      [userId, hash],
    );
  }

  async rotateRefreshHash(
    userId: string,
    oldHash: string,
    newHash: string,
  ): Promise<boolean> {
    const { rowCount } = await this.pool.query(
      'UPDATE users SET refresh_token_hash = $3, updated_at = now() WHERE id = $1 AND refresh_token_hash = $2',
      [userId, oldHash, newHash],
    );
    return rowCount === 1;
  }

  async recordLoginSuccess(userId: string, refreshHash: string): Promise<void> {
    await this.pool.query(
      `UPDATE users SET failed_login_count = 0, locked_until = NULL, refresh_token_hash = $2, updated_at = now()
       WHERE id = $1`,
      [userId, refreshHash],
    );
  }

  async recordLoginFailure(
    userId: string,
    maxFailures: number,
    lockUntil: Date,
  ): Promise<void> {
    await this.pool.query(
      `UPDATE users
       SET locked_until = CASE WHEN failed_login_count + 1 >= $2 THEN $3::timestamptz ELSE locked_until END,
           failed_login_count = CASE WHEN failed_login_count + 1 >= $2 THEN 0 ELSE failed_login_count + 1 END,
           updated_at = now()
       WHERE id = $1`,
      [userId, maxFailures, lockUntil],
    );
  }

  async markEmailVerified(userId: string, at: Date): Promise<void> {
    await this.pool.query(
      'UPDATE users SET email_verified_at = $2, updated_at = now() WHERE id = $1',
      [userId, at],
    );
  }

  async updateLanguage(userId: string, language: Language): Promise<void> {
    await this.pool.query(
      'UPDATE users SET language = $2, updated_at = now() WHERE id = $1',
      [userId, language],
    );
  }
}
