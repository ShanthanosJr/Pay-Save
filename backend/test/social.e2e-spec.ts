import { randomUUID } from 'node:crypto';
import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import request from 'supertest';
import { App } from 'supertest/types';
import {
  RecordingSender,
  TestUser,
  createTestApp,
  registerUser,
  verifyPhone,
} from './support/app';

const JPEG = Buffer.concat([
  Buffer.from([0xff, 0xd8, 0xff, 0xe0]),
  Buffer.alloc(64, 1),
]);
const PNG = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  Buffer.alloc(64, 2),
]);

const SENSITIVE = ['email', 'phone', 'phoneMasked', 'nic', 'nicMasked', 'age'];

describe('Profile, people and chat (e2e)', () => {
  let app: INestApplication<App>;
  let sender: RecordingSender;
  let pool: Pool;
  let a: TestUser;
  let b: TestUser;
  let c: TestUser;
  const http = () => request(app.getHttpServer());

  beforeAll(() => {
    pool = new Pool({ connectionString: process.env.DATABASE_URL });
  });
  afterAll(async () => {
    await pool.end();
  });

  const cleanup = async () => {
    const ids = `SELECT id FROM users WHERE email LIKE '%@social.e2e.test'`;
    await pool.query(
      `DELETE FROM circle_members WHERE circle_id IN (SELECT id FROM circles WHERE created_by IN (${ids}))`,
    );
    await pool.query(`DELETE FROM circles WHERE created_by IN (${ids})`);
    await pool.query('DELETE FROM otp_challenges');
    await pool.query(
      "DELETE FROM users WHERE email LIKE '%@social.e2e.test' OR is_community_officer AND display_name = 'E2E Officer'",
    );
  };

  beforeEach(async () => {
    await cleanup();
    ({ app, sender } = await createTestApp());
    a = await registerUser(app, sender, 1, 'Amaya Silva');
    b = await registerUser(app, sender, 2, 'Bimal Fernando');
    c = await registerUser(app, sender, 3, 'Chathuri Silva');
  });
  afterEach(async () => {
    await app.close();
  });

  describe('editing my profile', () => {
    it('updates name, username, bio, city and age; email is not editable', async () => {
      const res = await http()
        .patch('/users/me')
        .set(a.auth)
        .send({
          fullName: '  Amaya S. Silva ',
          username: '@Amaya.S',
          bio: 'Saving for a scooter',
          city: 'Kandy',
          age: 32,
        })
        .expect(200);
      expect(res.body).toMatchObject({
        fullName: 'Amaya S. Silva',
        username: 'amaya.s',
        bio: 'Saving for a scooter',
        city: 'Kandy',
        age: 32,
        email: 'user01@social.e2e.test',
      });

      await http()
        .patch('/users/me')
        .set(a.auth)
        .send({ email: 'new@social.e2e.test' })
        .expect(400);
      await http()
        .patch('/users/me')
        .set(a.auth)
        .send({ password: 'NewPassw0rd' })
        .expect(400);

      const cleared = await http()
        .patch('/users/me')
        .set(a.auth)
        .send({ bio: '', city: '' })
        .expect(200);
      expect(cleared.body).toMatchObject({
        bio: null,
        city: null,
        username: 'amaya.s',
      });
    });

    it('rejects bad values and a taken username', async () => {
      for (const bad of [
        { username: 'ab' },
        { username: 'has space' },
        { username: 'x'.repeat(31) },
        { bio: 'x'.repeat(161) },
        { age: 17 },
        { fullName: 'A' },
      ]) {
        await http().patch('/users/me').set(a.auth).send(bad).expect(400);
      }
      await http()
        .patch('/users/me')
        .set(a.auth)
        .send({ username: 'taken_name' })
        .expect(200);
      const res = await http()
        .patch('/users/me')
        .set(b.auth)
        .send({ username: 'Taken_Name' })
        .expect(409);
      expect(res.body).toMatchObject({ code: 'USERNAME_TAKEN' });
    });

    it('changes phone only with a verification token for the new number', async () => {
      const newPhone = '0779990001';
      await http()
        .post('/users/me/phone')
        .set(a.auth)
        .send({ phone: newPhone, phoneVerificationToken: 'garbage' })
        .expect(400);

      const tokenForOther = await verifyPhone(app, sender, '0779990002');
      await http()
        .post('/users/me/phone')
        .set(a.auth)
        .send({ phone: newPhone, phoneVerificationToken: tokenForOther })
        .expect(400);

      const token = await verifyPhone(app, sender, newPhone);
      const res = await http()
        .post('/users/me/phone')
        .set(a.auth)
        .send({ phone: newPhone, phoneVerificationToken: token })
        .expect(200);
      expect((res.body as { phoneMasked: string }).phoneMasked).toBe(
        '+9477*****01',
      );
      // the old number can now be registered, the new one cannot
      await http()
        .post('/auth/otp/request')
        .send({ phone: newPhone })
        .expect(409);
      await http()
        .post('/auth/login')
        .send({ identifier: newPhone, password: 'Passw0rdTest' })
        .expect(200);
    });
  });

  describe('profile photo', () => {
    it('uploads, is visible to other members, replaces and removes', async () => {
      await http().get(`/users/${a.id}/avatar`).set(b.auth).expect(404);

      const up = await http()
        .put('/users/me/avatar')
        .set(a.auth)
        .attach('file', JPEG, {
          filename: 'me.jpg',
          contentType: 'image/jpeg',
        })
        .expect(200);
      const url = (up.body as { avatarUrl: string }).avatarUrl;
      expect(url).toMatch(new RegExp(`^/users/${a.id}/avatar\\?v=\\d+$`));

      const seen = await http().get(url).set(b.auth).expect(200);
      expect(seen.headers['content-type']).toBe('image/jpeg');
      expect(seen.headers['x-content-type-options']).toBe('nosniff');
      expect(Buffer.compare(seen.body as Buffer, JPEG)).toBe(0);
      await http().get(url).expect(401);

      const profile = await http().get(`/people/${a.id}`).set(b.auth);
      expect((profile.body as { avatarUrl: string }).avatarUrl).toBe(url);

      const again = await http()
        .put('/users/me/avatar')
        .set(a.auth)
        .attach('file', PNG, { filename: 'me.png', contentType: 'image/png' })
        .expect(200);
      const url2 = (again.body as { avatarUrl: string }).avatarUrl;
      const png = await http().get(url2).set(b.auth).expect(200);
      expect(png.headers['content-type']).toBe('image/png');

      const removed = await http()
        .delete('/users/me/avatar')
        .set(a.auth)
        .expect(200);
      expect((removed.body as { avatarUrl: null }).avatarUrl).toBeNull();
      await http().get(`/users/${a.id}/avatar`).set(b.auth).expect(404);
    });

    it('trusts magic bytes, not the declared type, and caps the size', async () => {
      const svg = await http()
        .put('/users/me/avatar')
        .set(a.auth)
        .attach('file', Buffer.from('<svg onload="alert(1)"/>'), {
          filename: 'x.jpg',
          contentType: 'image/jpeg',
        })
        .expect(415);
      expect(svg.body).toMatchObject({ code: 'UNSUPPORTED_IMAGE' });

      const big = await http()
        .put('/users/me/avatar')
        .set(a.auth)
        .attach(
          'file',
          Buffer.concat([JPEG, Buffer.alloc(2 * 1024 * 1024)]),
          'big.jpg',
        )
        .expect(413);
      expect(big.body).toMatchObject({ code: 'IMAGE_TOO_LARGE' });

      const none = await http().put('/users/me/avatar').set(a.auth).expect(400);
      expect(none.body).toMatchObject({ code: 'IMAGE_REQUIRED' });
    });
  });

  describe('public profile', () => {
    it('never exposes phone, email, NIC or age', async () => {
      await http()
        .patch('/users/me')
        .set(a.auth)
        .send({ username: 'amaya', bio: 'Hi', city: 'Galle' });
      const res = await http().get(`/people/${a.id}`).set(b.auth).expect(200);
      const body = res.body as Record<string, unknown>;
      for (const key of SENSITIVE) expect(body).not.toHaveProperty(key);
      expect(JSON.stringify(body)).not.toMatch(/social\.e2e\.test|\+94|V"/);
      expect(body).toMatchObject({
        id: a.id,
        fullName: 'Amaya Silva',
        username: 'amaya',
        bio: 'Hi',
        city: 'Galle',
        verified: true,
        followersCount: 0,
        followingCount: 0,
        isMe: false,
      });
      const mine = await http().get(`/people/${a.id}`).set(a.auth).expect(200);
      expect((mine.body as { isMe: boolean }).isMe).toBe(true);
    });

    it('search and lists carry no sensitive fields either', async () => {
      const res = await http()
        .get('/people/search')
        .query({ q: 'silva' })
        .set(b.auth)
        .expect(200);
      for (const p of res.body as Record<string, unknown>[])
        for (const key of SENSITIVE) expect(p).not.toHaveProperty(key);
    });

    it('404s for unknown ids and 400s for malformed ones', async () => {
      await http().get(`/people/${randomUUID()}`).set(a.auth).expect(404);
      await http().get('/people/not-a-uuid').set(a.auth).expect(400);
      await http().get(`/people/${a.id}`).expect(401);
    });
  });

  describe('search and suggestions', () => {
    it('finds by name or username, excludes me, escapes wildcards', async () => {
      await http().patch('/users/me').set(b.auth).send({ username: 'bimal_f' });
      const silva = await http()
        .get('/people/search')
        .query({ q: 'SILVA' })
        .set(b.auth)
        .expect(200);
      expect((silva.body as { id: string }[]).map((p) => p.id).sort()).toEqual(
        [a.id, c.id].sort(),
      );

      const self = await http()
        .get('/people/search')
        .query({ q: 'silva' })
        .set(a.auth)
        .expect(200);
      expect((self.body as { id: string }[]).map((p) => p.id)).toEqual([c.id]);

      const handle = await http()
        .get('/people/search')
        .query({ q: 'bimal_' })
        .set(a.auth)
        .expect(200);
      expect((handle.body as { id: string }[])[0].id).toBe(b.id);

      const wildcard = await http()
        .get('/people/search')
        .query({ q: '%' })
        .set(a.auth)
        .expect(200);
      expect(wildcard.body).toEqual([]);

      await http().get('/people/search').set(a.auth).expect(400);
    });

    it('ranks people from my circles first, then friends of friends', async () => {
      const circle = await pool.query<{ id: string }>(
        `INSERT INTO circles (public_code, name, contribution_minor, interval, turn_rule, planned_cycles, created_by)
         VALUES ('E2E-SOC', 'E2E circle', 500000, 'monthly', 'fixed', 5, $1) RETURNING id`,
        [a.id],
      );
      await pool.query(
        `INSERT INTO circle_members (circle_id, user_id, role) VALUES ($1, $2, 'organizer'), ($1, $3, 'member')`,
        [circle.rows[0].id, a.id, c.id],
      );
      const d = await registerUser(app, sender, 4, 'Dilan Perera');
      await http().put(`/people/${b.id}/follow`).set(a.auth).expect(200);
      await http().put(`/people/${d.id}/follow`).set(b.auth).expect(200);

      const res = await http()
        .get('/people/suggestions')
        .set(a.auth)
        .expect(200);
      const list = res.body as {
        id: string;
        reason: string;
        sharedCircles: number;
      }[];
      expect(list[0]).toMatchObject({
        id: c.id,
        reason: 'shared_circle',
        sharedCircles: 1,
      });
      expect(list[1]).toMatchObject({ id: d.id, reason: 'mutual' });
      expect(list.map((p) => p.id)).not.toContain(b.id); // already followed
      expect(list.map((p) => p.id)).not.toContain(a.id);
    });
  });

  describe('follow and block', () => {
    it('follow updates counts both ways and is idempotent', async () => {
      const f = await http().put(`/people/${b.id}/follow`).set(a.auth);
      expect(f.status).toBe(200);
      await http().put(`/people/${b.id}/follow`).set(a.auth).expect(200);
      expect(f.body).toMatchObject({ isFollowing: true, followersCount: 1 });

      const bSeesA = await http().get(`/people/${a.id}`).set(b.auth);
      expect(bSeesA.body).toMatchObject({
        followsYou: true,
        followingCount: 1,
      });

      const followers = await http()
        .get(`/people/${b.id}/followers`)
        .set(c.auth)
        .expect(200);
      expect((followers.body as { id: string }[]).map((p) => p.id)).toEqual([
        a.id,
      ]);

      const un = await http()
        .delete(`/people/${b.id}/follow`)
        .set(a.auth)
        .expect(200);
      expect(un.body).toMatchObject({ isFollowing: false, followersCount: 0 });
      await http().put(`/people/${a.id}/follow`).set(a.auth).expect(400);
    });

    it('blocking hides me from them, ends follows and stops messages', async () => {
      await http().put(`/people/${a.id}/follow`).set(b.auth).expect(200);
      const chat = await http()
        .post('/chats')
        .set(a.auth)
        .send({ userId: b.id })
        .expect(200);
      const chatId = (chat.body as { id: string }).id;

      await http().put(`/people/${b.id}/block`).set(a.auth).expect(204);

      await http().get(`/people/${a.id}`).set(b.auth).expect(404);
      const search = await http()
        .get('/people/search')
        .query({ q: 'amaya' })
        .set(b.auth);
      expect(search.body).toEqual([]);
      const blocked = await http().get(`/people/${b.id}`).set(a.auth);
      expect(blocked.body).toMatchObject({
        blockedByMe: true,
        followsYou: false,
      });

      await http().put(`/people/${a.id}/follow`).set(b.auth).expect(404);
      const send = await http()
        .post(`/chats/${chatId}/messages`)
        .set(b.auth)
        .send({ clientMessageId: randomUUID(), body: 'hello?' })
        .expect(403);
      expect(send.body).toMatchObject({ code: 'BLOCKED' });
      await http()
        .post('/chats')
        .set(a.auth)
        .send({ userId: b.id })
        .expect(403);

      await http().delete(`/people/${b.id}/block`).set(a.auth).expect(204);
      await http()
        .post(`/chats/${chatId}/messages`)
        .set(b.auth)
        .send({ clientMessageId: randomUUID(), body: 'hello again' })
        .expect(201);
    });
  });

  describe('chat', () => {
    const send = (
      u: TestUser,
      chatId: string,
      body: string,
      id = randomUUID(),
    ) =>
      http()
        .post(`/chats/${chatId}/messages`)
        .set(u.auth)
        .send({ clientMessageId: id, body });

    it('opens one conversation per pair, sends, reads and counts unread', async () => {
      const open1 = await http()
        .post('/chats')
        .set(a.auth)
        .send({ userId: b.id })
        .expect(200);
      const open2 = await http()
        .post('/chats')
        .set(b.auth)
        .send({ userId: a.id })
        .expect(200);
      const chatId = (open1.body as { id: string }).id;
      expect((open2.body as { id: string }).id).toBe(chatId);
      expect(open1.body).toMatchObject({ peer: { id: b.id } });

      // empty conversations stay out of the inbox
      expect((await http().get('/chats').set(b.auth)).body).toEqual([]);

      await send(a, chatId, '  Hi Bimal  ').expect(201);
      await send(a, chatId, 'Paid my share today').expect(201);

      const inbox = await http().get('/chats').set(b.auth).expect(200);
      expect(inbox.body).toHaveLength(1);
      expect((inbox.body as unknown[])[0]).toMatchObject({
        id: chatId,
        unread: 2,
        peer: { id: a.id, fullName: 'Amaya Silva' },
        lastMessage: { body: 'Paid my share today', senderId: a.id },
      });
      const peer = (inbox.body as { peer: Record<string, unknown> }[])[0].peer;
      for (const key of SENSITIVE) expect(peer).not.toHaveProperty(key);
      expect((await http().get('/chats/unread').set(b.auth)).body).toEqual({
        count: 2,
      });
      expect((await http().get('/chats/unread').set(a.auth)).body).toEqual({
        count: 0,
      });

      const page = await http()
        .get(`/chats/${chatId}/messages`)
        .set(b.auth)
        .expect(200);
      const msgs = (page.body as { messages: { body: string; seq: number }[] })
        .messages;
      expect(msgs.map((m) => m.body)).toEqual([
        'Hi Bimal',
        'Paid my share today',
      ]);
      expect((page.body as { peerLastReadSeq: number }).peerLastReadSeq).toBe(
        msgs[1].seq,
      );

      const read = await http()
        .post(`/chats/${chatId}/read`)
        .set(b.auth)
        .expect(200);
      expect(read.body).toEqual({ lastReadSeq: msgs[1].seq });
      expect((await http().get('/chats/unread').set(b.auth)).body).toEqual({
        count: 0,
      });

      // polling for new messages after the last seen seq
      await send(b, chatId, 'Got it, thanks').expect(201);
      const newer = await http()
        .get(`/chats/${chatId}/messages`)
        .query({ after: msgs[1].seq })
        .set(a.auth)
        .expect(200);
      expect(
        (newer.body as { messages: { body: string }[] }).messages.map(
          (m) => m.body,
        ),
      ).toEqual(['Got it, thanks']);

      const older = await http()
        .get(`/chats/${chatId}/messages`)
        .query({ before: msgs[1].seq })
        .set(a.auth)
        .expect(200);
      expect(
        (older.body as { messages: { body: string }[] }).messages.map(
          (m) => m.body,
        ),
      ).toEqual(['Hi Bimal']);
    });

    it('a retried send with the same clientMessageId does not duplicate', async () => {
      const chatId = (
        (await http().post('/chats').set(a.auth).send({ userId: b.id }))
          .body as { id: string }
      ).id;
      const id = randomUUID();
      const first = await send(a, chatId, 'once', id).expect(201);
      const retry = await send(a, chatId, 'once', id).expect(201);
      expect((retry.body as { id: string }).id).toBe(
        (first.body as { id: string }).id,
      );
      const page = await http().get(`/chats/${chatId}/messages`).set(b.auth);
      expect((page.body as { messages: unknown[] }).messages).toHaveLength(1);

      const other = (
        (await http().post('/chats').set(a.auth).send({ userId: c.id }))
          .body as { id: string }
      ).id;
      await send(a, other, 'reuse', id).expect(409);
    });

    it('outsiders cannot read or post, and bodies are validated', async () => {
      const chatId = (
        (await http().post('/chats').set(a.auth).send({ userId: b.id }))
          .body as { id: string }
      ).id;
      await http().get(`/chats/${chatId}`).set(c.auth).expect(404);
      await http().get(`/chats/${chatId}/messages`).set(c.auth).expect(404);
      await send(c, chatId, 'sneaky').expect(404);
      await http().post(`/chats/${chatId}/read`).set(c.auth).expect(404);

      await send(a, chatId, '   ').expect(400);
      await send(a, chatId, 'x'.repeat(2001)).expect(400);
      await http()
        .post(`/chats/${chatId}/messages`)
        .set(a.auth)
        .send({ clientMessageId: 'not-a-uuid', body: 'x' })
        .expect(400);
      await http()
        .post('/chats')
        .set(a.auth)
        .send({ userId: a.id })
        .expect(400);
      await http()
        .post('/chats')
        .set(a.auth)
        .send({ userId: randomUUID() })
        .expect(404);
      await http().get('/chats').expect(401);
    });
  });

  it('community officers get no access to people or chat (rule 9)', async () => {
    await pool.query(
      `UPDATE users SET is_community_officer = true, display_name = 'E2E Officer' WHERE id = $1`,
      [c.id],
    );
    for (const path of [
      '/people/search?q=silva',
      '/people/suggestions',
      `/people/${a.id}`,
      '/chats',
    ]) {
      const res = await http().get(path).set(c.auth).expect(403);
      expect(res.body).toMatchObject({ code: 'FORBIDDEN' });
    }
    const sugg = await http().get('/people/suggestions').set(a.auth);
    expect((sugg.body as { id: string }[]).map((p) => p.id)).not.toContain(
      c.id,
    );
  });
});
