import { Inject, Injectable } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';

export const AVATAR_STORAGE = Symbol('AVATAR_STORAGE');
export const MAX_AVATAR_BYTES = 2 * 1024 * 1024;

export type AvatarContentType = 'image/jpeg' | 'image/png' | 'image/webp';

export interface StoredAvatar {
  contentType: AvatarContentType;
  data: Buffer;
  updatedAt: Date;
}

/** Where profile photos live. Postgres for now; S3 + signed URLs later. */
export interface AvatarStorage {
  put(
    userId: string,
    contentType: AvatarContentType,
    data: Buffer,
    at: Date,
  ): Promise<void>;
  get(userId: string): Promise<StoredAvatar | null>;
  remove(userId: string): Promise<void>;
}

@Injectable()
export class PgAvatarStorage implements AvatarStorage {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async put(
    userId: string,
    contentType: AvatarContentType,
    data: Buffer,
    at: Date,
  ): Promise<void> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(
        `INSERT INTO user_avatars (user_id, content_type, data, updated_at) VALUES ($1, $2, $3, $4)
         ON CONFLICT (user_id) DO UPDATE SET content_type = $2, data = $3, updated_at = $4`,
        [userId, contentType, data, at],
      );
      await client.query(
        'UPDATE users SET avatar_updated_at = $2, updated_at = now() WHERE id = $1',
        [userId, at],
      );
      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  async get(userId: string): Promise<StoredAvatar | null> {
    const { rows } = await this.pool.query<{
      content_type: AvatarContentType;
      data: Buffer;
      updated_at: Date;
    }>(
      'SELECT content_type, data, updated_at FROM user_avatars WHERE user_id = $1',
      [userId],
    );
    const r = rows[0];
    return r
      ? { contentType: r.content_type, data: r.data, updatedAt: r.updated_at }
      : null;
  }

  async remove(userId: string): Promise<void> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      await client.query('DELETE FROM user_avatars WHERE user_id = $1', [
        userId,
      ]);
      await client.query(
        'UPDATE users SET avatar_updated_at = NULL, updated_at = now() WHERE id = $1',
        [userId],
      );
      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }
}
