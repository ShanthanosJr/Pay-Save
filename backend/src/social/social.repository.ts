import { Inject, Injectable } from '@nestjs/common';
import { Pool, PoolClient } from 'pg';
import { PG_POOL } from '../database/database.module';

/**
 * Only non-sensitive columns are ever selected here: phone, email, NIC and
 * age stay inside the users module and the owner's /users/me response.
 */
export interface PersonRow {
  id: string;
  name: string;
  username: string | null;
  avatar_updated_at: Date | null;
  verified: boolean;
  is_following: boolean;
  follows_you: boolean;
}

export interface SuggestionRow extends PersonRow {
  shared_circles: number;
  mutual_count: number;
}

export interface ProfileRow extends PersonRow {
  bio: string | null;
  city: string | null;
  created_at: Date;
  followers_count: number;
  following_count: number;
  shared_circles: number;
  blocked_by_me: boolean;
  blocked_me: boolean;
}

export interface InboxRow extends PersonRow {
  conversation_id: string;
  last_seq: string;
  last_body: string;
  last_sender_id: string;
  last_at: Date;
  unread: number;
}

export interface MessageRow {
  id: string;
  seq: string;
  sender_id: string;
  client_message_id: string;
  body: string;
  created_at: Date;
}

// $1 is always the viewer.
const PERSON = `
  u.id, COALESCE(u.full_name, u.display_name) AS name, u.username, u.avatar_updated_at,
  u.phone_verified_at IS NOT NULL AS verified,
  EXISTS (SELECT 1 FROM user_follows f WHERE f.follower_id = $1 AND f.followee_id = u.id) AS is_following,
  EXISTS (SELECT 1 FROM user_follows f WHERE f.follower_id = u.id AND f.followee_id = $1) AS follows_you`;

const NOT_BLOCKED = `NOT EXISTS (
  SELECT 1 FROM user_blocks b
  WHERE (b.blocker_id = $1 AND b.blocked_id = u.id) OR (b.blocker_id = u.id AND b.blocked_id = $1))`;

const SHARED_CIRCLES = `(
  SELECT count(*)::int FROM circle_members a
  JOIN circle_members b ON b.circle_id = a.circle_id
  WHERE a.user_id = $1 AND b.user_id = u.id AND a.left_cycle IS NULL AND b.left_cycle IS NULL)`;

const escapeLike = (s: string) => s.replace(/[\\%_]/g, (c) => `\\${c}`);

@Injectable()
export class SocialRepository {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async isCommunityOfficer(userId: string): Promise<boolean> {
    const { rows } = await this.pool.query<{ o: boolean }>(
      'SELECT is_community_officer AS o FROM users WHERE id = $1',
      [userId],
    );
    return rows[0]?.o ?? false;
  }

  async search(me: string, q: string, limit: number): Promise<PersonRow[]> {
    const needle = q.toLowerCase();
    const like = escapeLike(needle);
    const { rows } = await this.pool.query<PersonRow>(
      `SELECT ${PERSON} FROM users u
       WHERE u.id <> $1 AND ${NOT_BLOCKED}
         AND (lower(COALESCE(u.full_name, u.display_name)) LIKE $2 ESCAPE '\\' OR u.username LIKE $2 ESCAPE '\\')
       ORDER BY (u.username = $4) DESC,
                (u.username LIKE $3 ESCAPE '\\') DESC,
                (lower(COALESCE(u.full_name, u.display_name)) LIKE $3 ESCAPE '\\') DESC,
                similarity(lower(COALESCE(u.full_name, u.display_name)), $4) DESC,
                u.created_at DESC
       LIMIT $5`,
      [me, `%${like}%`, `${like}%`, needle, limit],
    );
    return rows;
  }

  /** People who share a circle, are followed by people you follow, or follow you. */
  async suggestions(me: string, limit: number): Promise<SuggestionRow[]> {
    const { rows } = await this.pool.query<SuggestionRow>(
      `WITH mutual AS (
         SELECT f2.followee_id AS user_id, count(*)::int AS n
         FROM user_follows f1 JOIN user_follows f2 ON f2.follower_id = f1.followee_id
         WHERE f1.follower_id = $1 GROUP BY 1
       )
       SELECT * FROM (
         SELECT ${PERSON}, ${SHARED_CIRCLES} AS shared_circles,
                COALESCE(m.n, 0) AS mutual_count, u.created_at
         FROM users u LEFT JOIN mutual m ON m.user_id = u.id
         WHERE u.id <> $1 AND ${NOT_BLOCKED} AND NOT u.is_community_officer
       ) p
       WHERE NOT p.is_following
       ORDER BY p.shared_circles DESC, p.mutual_count DESC, p.follows_you DESC, p.created_at DESC
       LIMIT $2`,
      [me, limit],
    );
    return rows;
  }

  async profile(me: string, id: string): Promise<ProfileRow | null> {
    const { rows } = await this.pool.query<ProfileRow>(
      `SELECT ${PERSON}, u.bio, u.city, u.created_at,
              (SELECT count(*)::int FROM user_follows f WHERE f.followee_id = u.id) AS followers_count,
              (SELECT count(*)::int FROM user_follows f WHERE f.follower_id = u.id) AS following_count,
              ${SHARED_CIRCLES} AS shared_circles,
              EXISTS (SELECT 1 FROM user_blocks b WHERE b.blocker_id = $1 AND b.blocked_id = u.id) AS blocked_by_me,
              EXISTS (SELECT 1 FROM user_blocks b WHERE b.blocker_id = u.id AND b.blocked_id = $1) AS blocked_me
       FROM users u WHERE u.id = $2`,
      [me, id],
    );
    return rows[0] ?? null;
  }

  async followers(me: string, id: string, limit: number): Promise<PersonRow[]> {
    const { rows } = await this.pool.query<PersonRow>(
      `SELECT ${PERSON} FROM user_follows x JOIN users u ON u.id = x.follower_id
       WHERE x.followee_id = $2 AND ${NOT_BLOCKED}
       ORDER BY x.created_at DESC LIMIT $3`,
      [me, id, limit],
    );
    return rows;
  }

  async following(me: string, id: string, limit: number): Promise<PersonRow[]> {
    const { rows } = await this.pool.query<PersonRow>(
      `SELECT ${PERSON} FROM user_follows x JOIN users u ON u.id = x.followee_id
       WHERE x.follower_id = $2 AND ${NOT_BLOCKED}
       ORDER BY x.created_at DESC LIMIT $3`,
      [me, id, limit],
    );
    return rows;
  }

  async follow(me: string, id: string): Promise<void> {
    await this.pool.query(
      'INSERT INTO user_follows (follower_id, followee_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
      [me, id],
    );
  }

  async unfollow(me: string, id: string): Promise<void> {
    await this.pool.query(
      'DELETE FROM user_follows WHERE follower_id = $1 AND followee_id = $2',
      [me, id],
    );
  }

  /** Blocking also ends any follow in either direction. */
  async block(me: string, id: string): Promise<void> {
    await this.tx(async (c) => {
      await c.query(
        'INSERT INTO user_blocks (blocker_id, blocked_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
        [me, id],
      );
      await c.query(
        `DELETE FROM user_follows
         WHERE (follower_id = $1 AND followee_id = $2) OR (follower_id = $2 AND followee_id = $1)`,
        [me, id],
      );
    });
  }

  async unblock(me: string, id: string): Promise<void> {
    await this.pool.query(
      'DELETE FROM user_blocks WHERE blocker_id = $1 AND blocked_id = $2',
      [me, id],
    );
  }

  async isBlockedEitherWay(a: string, b: string): Promise<boolean> {
    const { rows } = await this.pool.query(
      `SELECT 1 FROM user_blocks
       WHERE (blocker_id = $1 AND blocked_id = $2) OR (blocker_id = $2 AND blocked_id = $1)`,
      [a, b],
    );
    return rows.length > 0;
  }

  // ---------- chats ----------

  async openConversation(me: string, peer: string): Promise<string> {
    return this.tx(async (c) => {
      const { rows } = await c.query<{ id: string }>(
        `INSERT INTO conversations (user_low, user_high)
         VALUES (LEAST($1::uuid, $2::uuid), GREATEST($1::uuid, $2::uuid))
         ON CONFLICT (user_low, user_high) DO UPDATE SET user_low = EXCLUDED.user_low
         RETURNING id`,
        [me, peer],
      );
      const id = rows[0].id;
      await c.query(
        `INSERT INTO conversation_members (conversation_id, user_id)
         VALUES ($1, $2), ($1, $3) ON CONFLICT DO NOTHING`,
        [id, me, peer],
      );
      return id;
    });
  }

  /** The other member's id, or null if `me` is not in this conversation. */
  async peerOf(me: string, conversationId: string): Promise<string | null> {
    const { rows } = await this.pool.query<{ user_id: string }>(
      `SELECT p.user_id FROM conversation_members m
       JOIN conversation_members p ON p.conversation_id = m.conversation_id AND p.user_id <> m.user_id
       WHERE m.conversation_id = $2 AND m.user_id = $1`,
      [me, conversationId],
    );
    return rows[0]?.user_id ?? null;
  }

  async person(me: string, id: string): Promise<PersonRow | null> {
    const { rows } = await this.pool.query<PersonRow>(
      `SELECT ${PERSON} FROM users u WHERE u.id = $2`,
      [me, id],
    );
    return rows[0] ?? null;
  }

  async inbox(me: string, limit: number): Promise<InboxRow[]> {
    const { rows } = await this.pool.query<InboxRow>(
      `SELECT ${PERSON}, c.id AS conversation_id,
              lm.seq AS last_seq, lm.body AS last_body, lm.sender_id AS last_sender_id, lm.created_at AS last_at,
              (SELECT count(*)::int FROM messages x
               WHERE x.conversation_id = c.id AND x.sender_id <> $1 AND x.seq > mine.last_read_seq) AS unread
       FROM conversation_members mine
       JOIN conversations c ON c.id = mine.conversation_id
       JOIN conversation_members pm ON pm.conversation_id = c.id AND pm.user_id <> $1
       JOIN users u ON u.id = pm.user_id
       JOIN LATERAL (
         SELECT seq, body, sender_id, created_at FROM messages
         WHERE conversation_id = c.id ORDER BY seq DESC LIMIT 1
       ) lm ON true
       WHERE mine.user_id = $1
       ORDER BY lm.seq DESC
       LIMIT $2`,
      [me, limit],
    );
    return rows;
  }

  async unreadTotal(me: string): Promise<number> {
    const { rows } = await this.pool.query<{ n: number }>(
      `SELECT count(*)::int AS n FROM conversation_members mine
       JOIN messages x ON x.conversation_id = mine.conversation_id
       WHERE mine.user_id = $1 AND x.sender_id <> $1 AND x.seq > mine.last_read_seq`,
      [me],
    );
    return rows[0].n;
  }

  async messages(
    conversationId: string,
    page: { before?: number; after?: number; limit: number },
  ): Promise<MessageRow[]> {
    const cols = 'id, seq, sender_id, client_message_id, body, created_at';
    if (page.after !== undefined) {
      const { rows } = await this.pool.query<MessageRow>(
        `SELECT ${cols} FROM messages WHERE conversation_id = $1 AND seq > $2 ORDER BY seq ASC LIMIT $3`,
        [conversationId, page.after, page.limit],
      );
      return rows;
    }
    const { rows } = await this.pool.query<MessageRow>(
      `SELECT ${cols} FROM messages
       WHERE conversation_id = $1 AND ($2::bigint IS NULL OR seq < $2)
       ORDER BY seq DESC LIMIT $3`,
      [conversationId, page.before ?? null, page.limit],
    );
    return rows.reverse();
  }

  async lastReadSeq(conversationId: string, userId: string): Promise<number> {
    const { rows } = await this.pool.query<{ s: string }>(
      'SELECT last_read_seq AS s FROM conversation_members WHERE conversation_id = $1 AND user_id = $2',
      [conversationId, userId],
    );
    return Number(rows[0]?.s ?? 0);
  }

  /**
   * Idempotent on (sender, clientMessageId): a retried send returns the
   * original message instead of a duplicate. Null means that id was already
   * used by this sender in a different conversation.
   */
  async send(
    conversationId: string,
    sender: string,
    clientMessageId: string,
    body: string,
  ): Promise<MessageRow | null> {
    return this.tx(async (c) => {
      const cols = 'id, seq, sender_id, client_message_id, body, created_at';
      const inserted = await c.query<MessageRow>(
        `INSERT INTO messages (conversation_id, sender_id, client_message_id, body)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (sender_id, client_message_id) DO NOTHING
         RETURNING ${cols}`,
        [conversationId, sender, clientMessageId, body],
      );
      if (inserted.rows[0]) {
        const m = inserted.rows[0];
        await c.query(
          'UPDATE conversations SET last_message_at = $2 WHERE id = $1',
          [conversationId, m.created_at],
        );
        await c.query(
          `UPDATE conversation_members SET last_read_seq = GREATEST(last_read_seq, $3)
           WHERE conversation_id = $1 AND user_id = $2`,
          [conversationId, sender, m.seq],
        );
        return m;
      }
      const existing = await c.query<MessageRow>(
        `SELECT ${cols} FROM messages
         WHERE sender_id = $1 AND client_message_id = $2 AND conversation_id = $3`,
        [sender, clientMessageId, conversationId],
      );
      return existing.rows[0] ?? null;
    });
  }

  async markRead(conversationId: string, userId: string): Promise<number> {
    const { rows } = await this.pool.query<{ s: string }>(
      `UPDATE conversation_members
       SET last_read_seq = GREATEST(last_read_seq,
         COALESCE((SELECT max(seq) FROM messages WHERE conversation_id = $1), 0))
       WHERE conversation_id = $1 AND user_id = $2
       RETURNING last_read_seq AS s`,
      [conversationId, userId],
    );
    return Number(rows[0]?.s ?? 0);
  }

  private async tx<T>(fn: (c: PoolClient) => Promise<T>): Promise<T> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const out = await fn(client);
      await client.query('COMMIT');
      return out;
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }
}
