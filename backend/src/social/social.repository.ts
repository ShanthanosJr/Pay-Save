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
  pal_status: PalStatus;
}

/** The viewer's pal relation to a person; 'outgoing' = I asked, 'incoming' = they asked. */
export type PalStatus = 'none' | 'pals' | 'outgoing' | 'incoming';

export interface PalRequestRow extends PersonRow {
  requested_at: Date;
  mutual_pals: number;
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
  pals_count: number;
  shared_circles: number;
  blocked_by_me: boolean;
  blocked_me: boolean;
}

export interface InboxRow extends PersonRow {
  conversation_id: string;
  last_seq: string;
  last_body: string;
  last_kind: MessageKind;
  last_deleted: boolean;
  last_sender_id: string;
  last_at: Date;
  unread: number;
  pinned: boolean;
  favourite: boolean;
}

export type MessageKind = 'text' | 'image' | 'video';

export interface MessageRow {
  id: string;
  seq: string;
  sender_id: string;
  client_message_id: string;
  body: string;
  created_at: Date;
  kind: MessageKind;
  deleted_at: Date | null;
  media_type: string | null;
  media_size: number | null;
  starred: boolean;
  reactions: { emoji: string; count: number; mine: boolean }[];
}

/** Message columns as seen by the viewer bound to `$<viewer>`. */
const messageSelect = (viewer: number) => `
  SELECT m.id, m.seq, m.sender_id, m.client_message_id, m.body, m.created_at, m.kind, m.deleted_at,
         a.content_type AS media_type, a.size AS media_size,
         EXISTS (SELECT 1 FROM message_stars s
                 WHERE s.message_id = m.id AND s.user_id = $${viewer}) AS starred,
         COALESCE((SELECT json_agg(json_build_object('emoji', r.emoji, 'count', r.n, 'mine', r.mine))
                   FROM (SELECT emoji, count(*)::int AS n, bool_or(user_id = $${viewer}) AS mine
                         FROM message_reactions WHERE message_id = m.id
                         GROUP BY emoji ORDER BY min(created_at)) r), '[]') AS reactions
  FROM messages m LEFT JOIN chat_attachments a ON a.message_id = m.id`;

// $1 is always the viewer.
const PERSON = `
  u.id, COALESCE(u.full_name, u.display_name) AS name, u.username, u.avatar_updated_at,
  u.phone_verified_at IS NOT NULL AS verified,
  EXISTS (SELECT 1 FROM user_follows f WHERE f.follower_id = $1 AND f.followee_id = u.id) AS is_following,
  EXISTS (SELECT 1 FROM user_follows f WHERE f.follower_id = u.id AND f.followee_id = $1) AS follows_you,
  CASE
    WHEN EXISTS (SELECT 1 FROM pals p
                 WHERE p.user_low = LEAST($1::uuid, u.id) AND p.user_high = GREATEST($1::uuid, u.id)) THEN 'pals'
    WHEN EXISTS (SELECT 1 FROM pal_requests r WHERE r.from_user = $1 AND r.to_user = u.id) THEN 'outgoing'
    WHEN EXISTS (SELECT 1 FROM pal_requests r
                 WHERE r.from_user = u.id AND r.to_user = $1 AND r.ignored_at IS NULL) THEN 'incoming'
    ELSE 'none'
  END AS pal_status`;

/** Pals as directed edges (a -> b and b -> a), so "pals of X" is a plain join. */
const PAL_EDGES = `(SELECT user_low AS a, user_high AS b FROM pals
                    UNION ALL SELECT user_high AS a, user_low AS b FROM pals)`;

const MUTUAL_PALS = `(
  SELECT count(*)::int FROM ${PAL_EDGES} e1 JOIN ${PAL_EDGES} e2 ON e2.b = e1.b
  WHERE e1.a = $1 AND e2.a = u.id)`;

const PALS_COUNT = `(SELECT count(*)::int FROM pals p WHERE p.user_low = u.id OR p.user_high = u.id)`;

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

  /**
   * People you might add as pals: shared circles first, then pals of your
   * pals, then people who follow you. Existing pals and open requests in
   * either direction are left out (incoming ones live on the requests page).
   */
  async suggestions(me: string, limit: number): Promise<SuggestionRow[]> {
    const { rows } = await this.pool.query<SuggestionRow>(
      `WITH mutual AS (
         SELECT e2.b AS user_id, count(*)::int AS n
         FROM ${PAL_EDGES} e1 JOIN ${PAL_EDGES} e2 ON e2.a = e1.b
         WHERE e1.a = $1 AND e2.b <> $1 GROUP BY 1
       )
       SELECT * FROM (
         SELECT ${PERSON}, ${SHARED_CIRCLES} AS shared_circles,
                COALESCE(m.n, 0) AS mutual_count, u.created_at
         FROM users u LEFT JOIN mutual m ON m.user_id = u.id
         WHERE u.id <> $1 AND ${NOT_BLOCKED} AND NOT u.is_community_officer
           AND NOT EXISTS (SELECT 1 FROM pal_requests r
                           WHERE (r.from_user = $1 AND r.to_user = u.id) OR (r.from_user = u.id AND r.to_user = $1))
       ) p
       WHERE p.pal_status = 'none'
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
              ${PALS_COUNT} AS pals_count,
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

  async pals(me: string, id: string, limit: number): Promise<PersonRow[]> {
    const { rows } = await this.pool.query<PersonRow>(
      `SELECT ${PERSON} FROM pals x
       JOIN users u ON u.id = CASE WHEN x.user_low = $2 THEN x.user_high ELSE x.user_low END
       WHERE (x.user_low = $2 OR x.user_high = $2) AND ${NOT_BLOCKED}
       ORDER BY x.since DESC LIMIT $3`,
      [me, id, limit],
    );
    return rows;
  }

  // ---------- pal requests ----------

  /** Requests waiting for `me`, and ones `me` sent (ignored ones still look pending to the sender). */
  async palRequests(
    me: string,
    box: 'received' | 'sent',
    limit: number,
  ): Promise<PalRequestRow[]> {
    const received = box === 'received';
    const { rows } = await this.pool.query<PalRequestRow>(
      `SELECT ${PERSON}, r.created_at AS requested_at, ${MUTUAL_PALS} AS mutual_pals
       FROM pal_requests r JOIN users u ON u.id = ${received ? 'r.from_user' : 'r.to_user'}
       WHERE ${received ? 'r.to_user = $1 AND r.ignored_at IS NULL' : 'r.from_user = $1'} AND ${NOT_BLOCKED}
       ORDER BY r.created_at DESC LIMIT $2`,
      [me, limit],
    );
    return rows;
  }

  async receivedPalRequestCount(me: string): Promise<number> {
    const { rows } = await this.pool.query<{ n: number }>(
      'SELECT count(*)::int AS n FROM pal_requests WHERE to_user = $1 AND ignored_at IS NULL',
      [me],
    );
    return rows[0].n;
  }

  async sentPalRequestCount(me: string): Promise<number> {
    const { rows } = await this.pool.query<{ n: number }>(
      'SELECT count(*)::int AS n FROM pal_requests WHERE from_user = $1',
      [me],
    );
    return rows[0].n;
  }

  /**
   * Sends a pal request. If they already asked me, this accepts instead.
   * A request they ignored stays as it is until `cooldownDays` have passed.
   */
  async requestPal(
    me: string,
    id: string,
    cooldownDays: number,
  ): Promise<'pals' | 'outgoing'> {
    return this.tx(async (c) => {
      if (await this.palsIn(c, me, id)) return 'pals';
      const theirs = await c.query(
        'SELECT 1 FROM pal_requests WHERE from_user = $2 AND to_user = $1 FOR UPDATE',
        [me, id],
      );
      if (theirs.rows.length > 0) {
        await this.makePals(c, me, id);
        return 'pals';
      }
      await c.query(
        `INSERT INTO pal_requests (from_user, to_user) VALUES ($1, $2)
         ON CONFLICT (from_user, to_user) DO UPDATE
           SET created_at = now(), ignored_at = NULL
           WHERE pal_requests.ignored_at IS NOT NULL
             AND pal_requests.ignored_at < now() - make_interval(days => $3)`,
        [me, id, cooldownDays],
      );
      return 'outgoing';
    });
  }

  /** False if `id` has no request waiting for `me`. */
  async acceptPal(me: string, id: string): Promise<boolean> {
    return this.tx(async (c) => {
      const { rows } = await c.query(
        'SELECT 1 FROM pal_requests WHERE from_user = $2 AND to_user = $1 FOR UPDATE',
        [me, id],
      );
      if (rows.length === 0) return false;
      await this.makePals(c, me, id);
      return true;
    });
  }

  async ignorePal(me: string, id: string): Promise<boolean> {
    const { rowCount } = await this.pool.query(
      `UPDATE pal_requests SET ignored_at = now()
       WHERE from_user = $2 AND to_user = $1 AND ignored_at IS NULL`,
      [me, id],
    );
    return rowCount === 1;
  }

  async withdrawPal(me: string, id: string): Promise<boolean> {
    const { rowCount } = await this.pool.query(
      'DELETE FROM pal_requests WHERE from_user = $1 AND to_user = $2',
      [me, id],
    );
    return rowCount === 1;
  }

  async removePal(me: string, id: string): Promise<boolean> {
    const { rowCount } = await this.pool.query(
      'DELETE FROM pals WHERE user_low = LEAST($1::uuid, $2::uuid) AND user_high = GREATEST($1::uuid, $2::uuid)',
      [me, id],
    );
    return rowCount === 1;
  }

  private async palsIn(c: PoolClient, a: string, b: string): Promise<boolean> {
    const { rows } = await c.query(
      'SELECT 1 FROM pals WHERE user_low = LEAST($1::uuid, $2::uuid) AND user_high = GREATEST($1::uuid, $2::uuid)',
      [a, b],
    );
    return rows.length > 0;
  }

  /** Pals follow each other, as LinkedIn connections do; requests between them are spent. */
  private async makePals(c: PoolClient, a: string, b: string): Promise<void> {
    await c.query(
      `DELETE FROM pal_requests
       WHERE (from_user = $1 AND to_user = $2) OR (from_user = $2 AND to_user = $1)`,
      [a, b],
    );
    await c.query(
      `INSERT INTO pals (user_low, user_high) VALUES (LEAST($1::uuid, $2::uuid), GREATEST($1::uuid, $2::uuid))
       ON CONFLICT DO NOTHING`,
      [a, b],
    );
    await c.query(
      `INSERT INTO user_follows (follower_id, followee_id) VALUES ($1, $2), ($2, $1)
       ON CONFLICT DO NOTHING`,
      [a, b],
    );
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

  /** Blocking also ends follows, pals and pal requests in either direction. */
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
      await c.query(
        `DELETE FROM pal_requests
         WHERE (from_user = $1 AND to_user = $2) OR (from_user = $2 AND to_user = $1)`,
        [me, id],
      );
      await c.query(
        'DELETE FROM pals WHERE user_low = LEAST($1::uuid, $2::uuid) AND user_high = GREATEST($1::uuid, $2::uuid)',
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
              lm.seq AS last_seq, lm.body AS last_body, lm.kind AS last_kind,
              (lm.deleted_at IS NOT NULL) AS last_deleted,
              lm.sender_id AS last_sender_id, lm.created_at AS last_at,
              (mine.pinned_at IS NOT NULL) AS pinned, mine.favourite,
              (SELECT count(*)::int FROM messages x
               WHERE x.conversation_id = c.id AND x.sender_id <> $1 AND x.seq > mine.last_read_seq
                 AND x.deleted_at IS NULL) AS unread
       FROM conversation_members mine
       JOIN conversations c ON c.id = mine.conversation_id
       JOIN conversation_members pm ON pm.conversation_id = c.id AND pm.user_id <> $1
       JOIN users u ON u.id = pm.user_id
       JOIN LATERAL (
         SELECT seq, body, kind, deleted_at, sender_id, created_at FROM messages
         WHERE conversation_id = c.id AND seq > mine.cleared_seq ORDER BY seq DESC LIMIT 1
       ) lm ON true
       WHERE mine.user_id = $1
       ORDER BY mine.pinned_at DESC NULLS LAST, lm.seq DESC
       LIMIT $2`,
      [me, limit],
    );
    return rows;
  }

  async unreadTotal(me: string): Promise<number> {
    const { rows } = await this.pool.query<{ n: number }>(
      `SELECT count(*)::int AS n FROM conversation_members mine
       JOIN messages x ON x.conversation_id = mine.conversation_id
       WHERE mine.user_id = $1 AND x.sender_id <> $1 AND x.seq > mine.last_read_seq
         AND x.deleted_at IS NULL`,
      [me],
    );
    return rows[0].n;
  }

  /** Messages the viewer has not cleared, oldest first. */
  async messages(
    conversationId: string,
    viewer: string,
    page: { before?: number; after?: number; limit: number },
  ): Promise<MessageRow[]> {
    const visible = `m.conversation_id = $1 AND m.seq > (
      SELECT cleared_seq FROM conversation_members WHERE conversation_id = $1 AND user_id = $2)`;
    if (page.after !== undefined) {
      const { rows } = await this.pool.query<MessageRow>(
        `${messageSelect(2)} WHERE ${visible} AND m.seq > $3 ORDER BY m.seq ASC LIMIT $4`,
        [conversationId, viewer, page.after, page.limit],
      );
      return rows;
    }
    const { rows } = await this.pool.query<MessageRow>(
      `${messageSelect(2)} WHERE ${visible} AND ($3::bigint IS NULL OR m.seq < $3)
       ORDER BY m.seq DESC LIMIT $4`,
      [conversationId, viewer, page.before ?? null, page.limit],
    );
    return rows.reverse();
  }

  async message(
    conversationId: string,
    viewer: string,
    messageId: string,
  ): Promise<MessageRow | null> {
    const { rows } = await this.pool.query<MessageRow>(
      `${messageSelect(2)} WHERE m.conversation_id = $1 AND m.id = $3`,
      [conversationId, viewer, messageId],
    );
    return rows[0] ?? null;
  }

  async attachment(
    conversationId: string,
    messageId: string,
  ): Promise<{ contentType: string; data: Buffer } | null> {
    const { rows } = await this.pool.query<{
      content_type: string;
      data: Buffer;
    }>(
      `SELECT a.content_type, a.data FROM chat_attachments a
       JOIN messages m ON m.id = a.message_id
       WHERE m.conversation_id = $1 AND m.id = $2 AND m.deleted_at IS NULL`,
      [conversationId, messageId],
    );
    return rows[0]
      ? { contentType: rows[0].content_type, data: rows[0].data }
      : null;
  }

  /** The sender takes a message back for everyone; its media is destroyed. */
  async deleteMessage(
    conversationId: string,
    sender: string,
    messageId: string,
  ): Promise<boolean> {
    return this.tx(async (c) => {
      const { rowCount } = await c.query(
        `UPDATE messages SET body = '', deleted_at = now()
         WHERE id = $1 AND conversation_id = $2 AND sender_id = $3 AND deleted_at IS NULL`,
        [messageId, conversationId, sender],
      );
      if (rowCount !== 1) return false;
      await c.query('DELETE FROM chat_attachments WHERE message_id = $1', [
        messageId,
      ]);
      await c.query('DELETE FROM message_reactions WHERE message_id = $1', [
        messageId,
      ]);
      await c.query('DELETE FROM message_stars WHERE message_id = $1', [
        messageId,
      ]);
      return true;
    });
  }

  async setReaction(
    messageId: string,
    userId: string,
    emoji: string | null,
  ): Promise<void> {
    if (emoji === null) {
      await this.pool.query(
        'DELETE FROM message_reactions WHERE message_id = $1 AND user_id = $2',
        [messageId, userId],
      );
      return;
    }
    await this.pool.query(
      `INSERT INTO message_reactions (message_id, user_id, emoji) VALUES ($1, $2, $3)
       ON CONFLICT (message_id, user_id) DO UPDATE SET emoji = $3, created_at = now()`,
      [messageId, userId, emoji],
    );
  }

  async setStar(
    messageId: string,
    userId: string,
    starred: boolean,
  ): Promise<void> {
    await this.pool.query(
      starred
        ? `INSERT INTO message_stars (message_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`
        : 'DELETE FROM message_stars WHERE message_id = $1 AND user_id = $2',
      [messageId, userId],
    );
  }

  async setChatFlags(
    conversationId: string,
    userId: string,
    flags: { pinned?: boolean; favourite?: boolean },
  ): Promise<void> {
    await this.pool.query(
      `UPDATE conversation_members SET
         pinned_at = CASE WHEN $3::boolean IS NULL THEN pinned_at
                          WHEN $3 THEN COALESCE(pinned_at, now()) ELSE NULL END,
         favourite = COALESCE($4::boolean, favourite)
       WHERE conversation_id = $1 AND user_id = $2`,
      [conversationId, userId, flags.pinned ?? null, flags.favourite ?? null],
    );
  }

  /** "Delete chat": hides the history for this person only. */
  async clearChat(conversationId: string, userId: string): Promise<void> {
    await this.pool.query(
      `UPDATE conversation_members SET pinned_at = NULL, favourite = false,
         cleared_seq = COALESCE((SELECT max(seq) FROM messages WHERE conversation_id = $1), 0),
         last_read_seq = GREATEST(last_read_seq,
           COALESCE((SELECT max(seq) FROM messages WHERE conversation_id = $1), 0))
       WHERE conversation_id = $1 AND user_id = $2`,
      [conversationId, userId],
    );
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
    media?: { kind: 'image' | 'video'; contentType: string; data: Buffer },
  ): Promise<MessageRow | null> {
    const id = await this.tx(async (c) => {
      const inserted = await c.query<{
        id: string;
        seq: string;
        created_at: Date;
      }>(
        `INSERT INTO messages (conversation_id, sender_id, client_message_id, body, kind)
         VALUES ($1, $2, $3, $4, $5)
         ON CONFLICT (sender_id, client_message_id) DO NOTHING
         RETURNING id, seq, created_at`,
        [conversationId, sender, clientMessageId, body, media?.kind ?? 'text'],
      );
      const m = inserted.rows[0];
      if (m) {
        if (media)
          await c.query(
            `INSERT INTO chat_attachments (message_id, content_type, size, data)
             VALUES ($1, $2, $3, $4)`,
            [m.id, media.contentType, media.data.length, media.data],
          );
        await c.query(
          'UPDATE conversations SET last_message_at = $2 WHERE id = $1',
          [conversationId, m.created_at],
        );
        await c.query(
          `UPDATE conversation_members SET last_read_seq = GREATEST(last_read_seq, $3)
           WHERE conversation_id = $1 AND user_id = $2`,
          [conversationId, sender, m.seq],
        );
        return m.id;
      }
      const existing = await c.query<{ id: string }>(
        `SELECT id FROM messages
         WHERE sender_id = $1 AND client_message_id = $2 AND conversation_id = $3`,
        [sender, clientMessageId, conversationId],
      );
      return existing.rows[0]?.id ?? null;
    });
    return id ? this.message(conversationId, sender, id) : null;
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
