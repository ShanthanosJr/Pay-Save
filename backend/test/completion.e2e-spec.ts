import { randomUUID } from 'node:crypto';
import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { Pool } from 'pg';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from './../src/app.module';
import { configureApp } from './../src/app.setup';
import { addDays, localDate } from './../src/circles/domain/schedule';
import { CLOCK, Clock } from './../src/common/clock/clock';
import {
  EMAIL_TRANSPORT,
  EmailMessage,
  SMS_TRANSPORT,
  SmsMessage,
} from './../src/messaging/messaging.types';
import { RemindersService } from './../src/reminders/reminders.service';
import { TestDatabase, createTestDatabase } from './support/test-db';

interface User {
  id: string;
  name: string;
  auth: { Authorization: string };
}
interface Detail {
  id: string;
  status: string;
  plannedCycles: number;
  members: { userId: string; payoutPosition: number | null }[];
  cycles: { number: number; recipientUserId: string; status: string }[];
  current: null | { number: number; totals: { unpaid: { count: number } } };
}
interface Note {
  id: string;
  kind: string;
  read: boolean;
  payload: Record<string, unknown>;
}

class TestClock implements Clock {
  offsetMs = 0;
  now(): Date {
    return new Date(Date.now() + this.offsetMs);
  }
  setDay(date: string): void {
    this.offsetMs = Date.parse(`${date}T06:00:00Z`) - Date.now();
  }
}

/** Reminders, removal, statements and the community tier, end to end. */
describe('Reminders, member removal, statements and community (e2e)', () => {
  let db: TestDatabase;
  let app: INestApplication<App>;
  let pool: Pool;
  const clock = new TestClock();
  const sms: SmsMessage[] = [];
  const mail: EmailMessage[] = [];
  const savedUrl = process.env.DATABASE_URL;
  const http = () => request(app.getHttpServer());
  let seq = 0;

  const codeFrom = (text: string) => /\d{6}/.exec(text)![0];

  async function register(name: string): Promise<User> {
    seq += 1;
    const n = String(seq).padStart(2, '0');
    const phone = `07733000${n}`;
    await http().post('/auth/otp/request').send({ phone }).expect(200);
    const v = await http()
      .post('/auth/otp/verify')
      .send({ phone, code: codeFrom(sms.at(-1)!.text) })
      .expect(200);
    const res = await http()
      .post('/auth/register')
      .send({
        fullName: name,
        age: 30,
        nic: `8720000${n}V`,
        phone,
        email: `c${n}@complete.e2e.test`,
        password: 'Passw0rdTest',
        phoneVerificationToken: (v.body as { phoneVerificationToken: string })
          .phoneVerificationToken,
      })
      .expect(201);
    const b = res.body as { accessToken: string; user: { id: string } };
    await http()
      .post('/users/me/payout-methods')
      .set({ Authorization: `Bearer ${b.accessToken}` })
      .send({ kind: 'cash', note: 'Hand it to me' })
      .expect(201);
    return {
      id: b.user.id,
      name,
      auth: { Authorization: `Bearer ${b.accessToken}` },
    };
  }

  const makePals = (a: User, b: User) =>
    pool.query(
      `INSERT INTO pals (user_low, user_high)
       VALUES (LEAST($1::uuid, $2::uuid), GREATEST($1::uuid, $2::uuid))`,
      [a.id, b.id],
    );

  /** An active circle of `people`, organizer first, in that turn order. */
  async function startedCircle(people: User[], dueInDays = 10) {
    const [org, ...rest] = people;
    const created = (
      await http()
        .post('/circles')
        .set(org.auth)
        .send({
          name: 'Temple Seettu',
          contributionMinor: 500_000,
          interval: 'monthly',
          turnRule: 'fixed',
          plannedCycles: people.length,
          firstDueDate: addDays(localDate(clock.now()), dueInDays),
        })
        .expect(201)
    ).body as Detail & { joinCode: string };
    for (const p of rest)
      await http()
        .post('/circles/join')
        .set(p.auth)
        .send({ code: created.joinCode })
        .expect(200);
    const started = await http()
      .post(`/circles/${created.id}/start`)
      .set(org.auth)
      .send({ order: people.map((p) => p.id) })
      .expect(200);
    return started.body as Detail;
  }

  const pay = async (circleId: string, who: User, cycleNumber: number) =>
    (
      (
        await http()
          .post(`/circles/${circleId}/contributions`)
          .set(who.auth)
          .send({ cycleNumber, method: 'cash', clientEntryId: randomUUID() })
          .expect(201)
      ).body as { entry: { id: string; reference: string } }
    ).entry;

  const inbox = async (u: User) =>
    (await http().get('/notifications').set(u.auth).expect(200)).body as {
      items: Note[];
      unread: number;
    };

  let org: User;
  let amaya: User;
  let bimal: User;
  let chathu: User;
  let dilan: User;

  beforeAll(async () => {
    db = await createTestDatabase(savedUrl as string);
    process.env.DATABASE_URL = db.url;
    pool = new Pool({ connectionString: db.url });
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(CLOCK)
      .useValue(clock)
      .overrideProvider(SMS_TRANSPORT)
      .useValue({ send: (m: SmsMessage) => Promise.resolve(void sms.push(m)) })
      .overrideProvider(EMAIL_TRANSPORT)
      .useValue({
        send: (m: EmailMessage) => Promise.resolve(void mail.push(m)),
      })
      .compile();
    app = moduleRef.createNestApplication<INestApplication<App>>();
    configureApp(app);
    await app.init();
    org = await register('Kamala Silva');
    amaya = await register('Amaya Perera');
    bimal = await register('Bimal Fernando');
    chathu = await register('Chathuri Dias');
    dilan = await register('Dilan Raj');
    for (const p of [amaya, bimal, chathu, dilan]) await makePals(org, p);
  }, 60_000);

  afterAll(async () => {
    await app?.close();
    await pool?.end();
    process.env.DATABASE_URL = savedUrl;
    await db?.drop();
  });

  describe('real delivery path', () => {
    it('the registration code went out as an SMS in the default language', () => {
      expect(sms[0].to).toBe('+94773300001');
      expect(sms[0].text).toMatch(/^Pay&Save code: \d{6}\./);
    });

    it('email verification is sent by email and unlocks email reminders', async () => {
      const before = mail.length;
      await http().post('/users/me/email/otp').set(amaya.auth).expect(200);
      expect(mail).toHaveLength(before + 1);
      expect(mail.at(-1)).toMatchObject({
        to: 'c02@complete.e2e.test',
        subject: 'Verify your email for Pay&Save',
      });
      await http()
        .post('/users/me/email/verify')
        .set(amaya.auth)
        .send({ code: codeFrom(mail.at(-1)!.text) })
        .expect(200);
    });
  });

  describe('notifications', () => {
    it('every entry about you reaches your inbox, and can be marked read', async () => {
      const circle = await startedCircle([org, amaya, bimal]);
      expect((await inbox(amaya)).items.map((n) => n.kind)).toContain(
        'circle_started',
      );
      const entry = await pay(circle.id, amaya, 1);
      const orgBox = await inbox(org);
      expect(orgBox.items[0]).toMatchObject({
        kind: 'payment_recorded',
        read: false,
        payload: { reference: entry.reference, amountMinor: 500_000 },
      });

      await http()
        .post(`/circles/${circle.id}/contributions/${entry.id}/reject`)
        .set(org.auth)
        .send({ reason: 'No transfer received' })
        .expect(201);
      const mine = await inbox(amaya);
      expect(mine.items[0]).toMatchObject({
        kind: 'payment_rejected',
        payload: { reason: 'No transfer received' },
      });
      expect(mine.unread).toBeGreaterThan(0);

      const one = await http()
        .post('/notifications/read')
        .set(amaya.auth)
        .send({ ids: [mine.items[0].id] })
        .expect(200);
      expect((one.body as { unread: number }).unread).toBe(mine.unread - 1);
      await http()
        .post('/notifications/read')
        .set(amaya.auth)
        .send({})
        .expect(200);
      expect((await inbox(amaya)).unread).toBe(0);
      // nobody else's inbox is reachable
      await http().get('/notifications').expect(401);
      expect(
        (await inbox(bimal)).items.some((n) => n.kind === 'payment_rejected'),
      ).toBe(false);
    });
  });

  describe('reminders (FR-03, U-06)', () => {
    it('are off by default, need a choice, and fire once per chosen day', async () => {
      const today = localDate(new Date());
      clock.setDay(today);
      const circle = await startedCircle([org, amaya, bimal], 5);
      const url = `/circles/${circle.id}/reminders`;
      const initial = await http().get(url).set(amaya.auth).expect(200);
      expect(initial.body).toMatchObject({
        enabled: false,
        daysBefore: [],
        channels: [],
        suggestedDaysBefore: [3],
      });
      await http()
        .put(url)
        .set(amaya.auth)
        .send({ enabled: true, daysBefore: [], channels: [] })
        .expect(400);
      // bimal's email is not verified
      await http()
        .put(url)
        .set(bimal.auth)
        .send({ enabled: true, daysBefore: [3], channels: ['email'] })
        .expect(409);
      await http()
        .put(url)
        .set(amaya.auth)
        .send({ enabled: true, daysBefore: [3, 0], channels: ['sms', 'email'] })
        .expect(200);

      const reminders = app.get(RemindersService);
      const count = async (u: User, kind: string) =>
        (await inbox(u)).items.filter((n) => n.kind === kind).length;
      const smsBefore = sms.length;
      const mailBefore = mail.length;

      expect(await reminders.run(clock.now())).toBe(0); // 5 days out
      clock.setDay(addDays(today, 2)); // 3 days out
      expect(await reminders.run(clock.now())).toBe(1);
      expect(await reminders.run(clock.now())).toBe(0); // re-run is a no-op
      expect(await count(amaya, 'reminder_due')).toBe(1);
      expect(await count(bimal, 'reminder_due')).toBe(0);
      expect(sms).toHaveLength(smsBefore + 1);
      expect(sms.at(-1)!.text).toContain('Temple Seettu');
      expect(sms.at(-1)!.text).toContain('LKR 5,000.00');
      expect(mail).toHaveLength(mailBefore + 1);

      // paying stops further reminders
      clock.setDay(addDays(today, 5));
      await pay(circle.id, amaya, 1);
      expect(await reminders.run(clock.now())).toBe(0);
    });

    it('overdue is sent once, and the organizer can nudge once a day', async () => {
      const today = localDate(new Date());
      clock.setDay(today);
      const circle = await startedCircle([org, amaya, bimal], 1);
      await http()
        .put(`/circles/${circle.id}/reminders`)
        .set(bimal.auth)
        .send({ enabled: true, daysBefore: [1], channels: [] })
        .expect(200);
      const reminders = app.get(RemindersService);
      const mineIn = async (u: User, kind: string) =>
        (await inbox(u)).items.filter(
          (n) => n.kind === kind && n.payload.dueDate === addDays(today, 1),
        ).length;

      clock.setDay(addDays(today, 3));
      await reminders.run(clock.now());
      clock.setDay(addDays(today, 4));
      await reminders.run(clock.now());
      expect(await mineIn(bimal, 'reminder_overdue')).toBe(1);

      const nudge = `/circles/${circle.id}/members/${amaya.id}/remind`;
      await http().post(nudge).set(amaya.auth).expect(403);
      await http().post(nudge).set(org.auth).expect(200);
      await http().post(nudge).set(org.auth).expect(429);
      expect(await mineIn(amaya, 'organizer_nudge')).toBe(1);
      await pay(circle.id, amaya, 1);
      clock.setDay(addDays(today, 5));
      await http().post(nudge).set(org.auth).expect(409);
      clock.setDay(today);
    });
  });

  describe('member removal (FR-05)', () => {
    it('draft: a member can leave, the organizer can remove, and both may return', async () => {
      const created = (
        await http()
          .post('/circles')
          .set(org.auth)
          .send({
            name: 'Draft Seettu',
            contributionMinor: 500_000,
            interval: 'monthly',
            turnRule: 'fixed',
            plannedCycles: 4,
            firstDueDate: addDays(localDate(clock.now()), 10),
          })
          .expect(201)
      ).body as Detail & { joinCode: string };
      const join = (u: User) =>
        http()
          .post('/circles/join')
          .set(u.auth)
          .send({ code: created.joinCode });
      await join(amaya).expect(200);
      await join(bimal).expect(200);

      await http()
        .post(`/circles/${created.id}/leave`)
        .set(org.auth)
        .expect(409);
      await http()
        .post(`/circles/${created.id}/leave`)
        .set(amaya.auth)
        .expect(204);
      await http().get(`/circles/${created.id}`).set(amaya.auth).expect(404);
      await http()
        .post(`/circles/${created.id}/members/${bimal.id}/remove`)
        .set(amaya.auth)
        .send({})
        .expect(404);
      const after = await http()
        .post(`/circles/${created.id}/members/${bimal.id}/remove`)
        .set(org.auth)
        .send({})
        .expect(200);
      expect((after.body as Detail).members).toHaveLength(1);
      expect((await inbox(bimal)).items[0].kind).toBe('member_removed');
      await join(amaya).expect(200);

      const ledger = await http()
        .get(`/circles/${created.id}/ledger?scope=all`)
        .set(org.auth)
        .expect(200);
      const types = (
        ledger.body as { entries: { type: string }[] }
      ).entries.map((e) => e.type);
      expect(types.filter((t) => t === 'member_removed')).toHaveLength(2);
      expect(types.filter((t) => t === 'member_added')).toHaveLength(4);
    });

    it('running circle: needs a reason, drops one cycle and keeps the record', async () => {
      const circle = await startedCircle([org, amaya, bimal, chathu]);
      const remove = (u: User, body: object = { reason: 'Moved abroad' }) =>
        http()
          .post(`/circles/${circle.id}/members/${u.id}/remove`)
          .set(org.auth)
          .send(body);
      await remove(bimal, {}).expect(400);
      await remove(org).expect(409);

      // amaya has a payment waiting: settle it first
      const entry = await pay(circle.id, amaya, 1);
      await remove(amaya).expect((r) =>
        expect(r.body).toMatchObject({ code: 'MEMBER_HAS_PAYMENT' }),
      );
      await http()
        .post(`/circles/${circle.id}/contributions/${entry.id}/verify`)
        .set(org.auth)
        .expect(201);

      const res = await remove(bimal).expect(200);
      const d = res.body as Detail;
      expect(d.plannedCycles).toBe(3);
      expect(d.cycles.map((c) => c.recipientUserId)).toEqual([
        org.id,
        amaya.id,
        chathu.id,
      ]);
      expect(d.members.map((x) => [x.userId, x.payoutPosition])).toEqual([
        [org.id, 1],
        [amaya.id, 2],
        [chathu.id, 3],
      ]);
      expect(d.current!.totals.unpaid.count).toBe(2);
      await http().get(`/circles/${circle.id}`).set(bimal.auth).expect(404);

      const ledger = await http()
        .get(`/circles/${circle.id}/ledger?scope=all`)
        .set(org.auth)
        .expect(200);
      const removed = (
        ledger.body as {
          entries: { type: string; note: string; cycleNumber: number }[];
        }
      ).entries.find((e) => e.type === 'member_removed');
      expect(removed).toMatchObject({ note: 'Moved abroad', cycleNumber: 1 });

      // someone who already received the pot cannot be let go
      await http()
        .post(`/circles/${circle.id}/cycles/1/close`)
        .set(org.auth)
        .send({ acknowledgeUnpaid: 2 })
        .expect(200);
      expect((await inbox(amaya)).items[0].kind).toBe('cycle_closed');
      const two = await pay(circle.id, org, 2);
      await http()
        .post(`/circles/${circle.id}/contributions/${two.id}/verify`)
        .set(org.auth)
        .expect(201);
      await http()
        .post(`/circles/${circle.id}/cycles/2/close`)
        .set(org.auth)
        .send({ acknowledgeUnpaid: 2 })
        .expect(200);
      await remove(amaya).expect((r) =>
        expect(r.body).toMatchObject({ code: 'MEMBER_ALREADY_PAID_OUT' }),
      );
    });
  });

  describe('verified statement (FR-11)', () => {
    it('lists only verified payments, verifies publicly, and breaks on tampering', async () => {
      const circle = await startedCircle([org, amaya, bimal]);
      const base = `/circles/${circle.id}`;
      await http()
        .post(`${base}/statements`)
        .set(amaya.auth)
        .expect(409)
        .expect((r) =>
          expect(r.body).toMatchObject({ code: 'NOTHING_VERIFIED' }),
        );

      const mine = await pay(circle.id, amaya, 1);
      await pay(circle.id, bimal, 1); // recorded, never verified
      await http()
        .post(`${base}/contributions/${mine.id}/verify`)
        .set(org.auth)
        .expect(201);

      const res = await http()
        .post(`${base}/statements`)
        .set(amaya.auth)
        .expect(201);
      const s = res.body as {
        id: string;
        verificationCode: string;
        verifyUrl: string;
        contributions: Record<string, unknown>;
        lines: { reference: string }[];
        chainHeadHash: string;
      };
      expect(s.verificationCode).toMatch(
        /^PS-[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{4}$/,
      );
      expect(s.contributions).toEqual({
        count: 1,
        unitMinor: 500_000,
        totalMinor: 500_000,
        entryIds: [mine.id],
      });
      expect(s.lines.map((l) => l.reference)).toEqual([mine.reference]);
      expect(s.verifyUrl).toContain(`/verify/${s.verificationCode}`);

      // the file: owner only
      const pdf = await http()
        .get(`/statements/${s.id}/file`)
        .set(amaya.auth)
        .buffer(true)
        .parse((r, cb) => {
          const chunks: Buffer[] = [];
          r.on('data', (c: Buffer) => chunks.push(c));
          r.on('end', () => cb(null, Buffer.concat(chunks)));
        })
        .expect(200);
      expect(pdf.headers['content-type']).toBe('application/pdf');
      expect((pdf.body as Buffer).subarray(0, 5).toString()).toBe('%PDF-');
      const csv = await http()
        .get(`/statements/${s.id}/file?format=csv`)
        .set(amaya.auth)
        .expect(200);
      expect(csv.text).toContain(`1,${mine.reference},cash`);
      expect(csv.text).toContain(s.verificationCode);
      await http().get(`/statements/${s.id}/file`).set(org.auth).expect(404);
      await http().get(`/statements/${s.id}/file`).expect(401);

      // public check: no account, lower case and missing dashes tolerated
      const loose = s.verificationCode.toLowerCase().replace(/-/g, ' ');
      const check = await http().get(`/statements/verify/${loose}`).expect(200);
      expect(check.body).toEqual({
        valid: true,
        ledgerIntact: true,
        issuedAt: expect.any(String) as string,
        holderInitials: 'A. P.',
        circleCode: expect.stringMatching(/^RC-\d+$/) as string,
        contributions: { count: 1, unitMinor: 500_000, totalMinor: 500_000 },
        chainHeadHash: s.chainHeadHash,
      });
      expect(JSON.stringify(check.body)).not.toContain('Amaya');
      const page = await http()
        .get(`/verify/${s.verificationCode}`)
        .expect(200);
      expect(page.text).toContain('Genuine statement');
      expect(page.text).not.toContain('Amaya');
      const bogus = await http().get('/statements/verify/PS-AAAA-BBBB-CCCC');
      expect(bogus.body).toEqual({ valid: false });
      const xss = await http().get(
        '/verify/%3Cscript%3Ealert(1)%3C%2Fscript%3E',
      );
      expect(xss.text).not.toContain('<script>');

      // a later honest entry does not disturb an issued statement
      await pay(circle.id, org, 1);
      expect(
        (await http().get(`/statements/verify/${s.verificationCode}`)).body,
      ).toMatchObject({ valid: true, ledgerIntact: true });

      // someone with database access rewrites history
      await pool.query(
        'ALTER TABLE ledger_entries DISABLE TRIGGER ledger_no_update',
      );
      await pool.query(
        'UPDATE ledger_entries SET amount_minor = 900000 WHERE id = $1',
        [mine.id],
      );
      await pool.query(
        'ALTER TABLE ledger_entries ENABLE TRIGGER ledger_no_update',
      );
      expect(
        (await http().get(`/statements/verify/${s.verificationCode}`)).body,
      ).toMatchObject({ valid: true, ledgerIntact: false });
      expect(
        (await http().get(`/verify/${s.verificationCode}`)).text,
      ).toContain('Record changed since this statement');
      await http()
        .post(`${base}/statements`)
        .set(amaya.auth)
        .expect(409)
        .expect((r) =>
          expect(r.body).toMatchObject({ code: 'LEDGER_INTEGRITY' }),
        );
    });
  });

  describe('community tier (FR-10, U-05)', () => {
    let officer: User;
    const PRIVATE = /Kamala|Amaya|Bimal|Chathuri|Dilan|0773300|complete\.e2e/;

    beforeAll(async () => {
      officer = await register('Sunil Officer');
      await pool.query(
        'UPDATE users SET is_community_officer = true WHERE id = $1',
        [officer.id],
      );
    });

    it('a circle appears to officers only when every member agreed and it has 5+ members', async () => {
      const five = await startedCircle([org, amaya, bimal, chathu, dilan]);
      const url = `/circles/${five.id}/community`;
      const overview = async () =>
        (await http().get('/community/overview').set(officer.auth).expect(200))
          .body as { circles: Record<string, unknown>[] };

      await http().get('/community/overview').set(org.auth).expect(403);
      expect((await overview()).circles).toEqual([]);
      for (const u of [org, amaya, bimal, chathu])
        await http().put(`${url}/consent`).set(u.auth).send({ granted: true });
      const partial = await http().get(url).set(dilan.auth).expect(200);
      expect(partial.body).toEqual({
        shared: false,
        mine: false,
        granted: 4,
        needed: 5,
        largeEnough: true,
        minimumMembers: 5,
      });
      expect((await overview()).circles).toEqual([]);

      await http()
        .put(`${url}/consent`)
        .set(dilan.auth)
        .send({ granted: true });
      const entry = await pay(five.id, amaya, 1);
      await http()
        .post(`/circles/${five.id}/contributions/${entry.id}/verify`)
        .set(org.auth);
      const shared = await overview();
      expect(shared.circles).toEqual([
        {
          circleCode: expect.stringMatching(/^RC-\d+$/) as string,
          members: 5,
          onTimeRatePct: expect.any(Number) as number,
          cyclesRun: 5,
        },
      ]);
      expect(JSON.stringify(shared)).not.toMatch(PRIVATE);

      // one member changing their mind withdraws the whole circle
      await http()
        .put(`${url}/consent`)
        .set(bimal.auth)
        .send({ granted: false });
      expect((await overview()).circles).toEqual([]);

      // a three-member circle never shows, even with everyone agreed
      const three = await startedCircle([org, amaya, bimal]);
      for (const u of [org, amaya, bimal])
        await http()
          .put(`/circles/${three.id}/community/consent`)
          .set(u.auth)
          .send({ granted: true });
      expect((await overview()).circles).toEqual([]);
    });

    it('dispute: raised, consented by all concerned, then only those entries, logged and notified', async () => {
      const circle = await startedCircle([org, amaya, bimal]);
      const base = `/circles/${circle.id}`;
      const mine = await pay(circle.id, amaya, 1);
      const other = await pay(circle.id, bimal, 1);
      await http()
        .post(`${base}/contributions/${mine.id}/reject`)
        .set(org.auth)
        .send({ reason: 'Amaya, I did not get it' })
        .expect(201);

      // not about me
      await http()
        .post(`${base}/disputes`)
        .set(amaya.auth)
        .send({ entryIds: [other.id], category: 'other' })
        .expect(403);
      const raised = await http()
        .post(`${base}/disputes`)
        .set(amaya.auth)
        .send({ entryIds: [mine.id], category: 'payment_rejected' })
        .expect(201);
      const dispute = raised.body as { id: string; status: string };
      expect(raised.body).toMatchObject({
        status: 'awaiting_consent',
        raisedByYou: true,
        consent: { needed: 2, granted: 1, mine: true },
        entries: [{ entryId: mine.id, reference: mine.reference }],
      });
      expect((await inbox(org)).items[0].kind).toBe(
        'dispute_consent_requested',
      );

      // before consent the officer sees nothing
      const evidence = `/community/disputes/${dispute.id}/evidence`;
      await http().get(evidence).set(officer.auth).expect(404);
      expect(
        (await http().get('/community/disputes').set(officer.auth)).body,
      ).toEqual({ disputes: [] });
      // bimal is not concerned
      await http()
        .put(`${base}/disputes/${dispute.id}/consent`)
        .set(bimal.auth)
        .send({ granted: true })
        .expect(404);
      await http()
        .put(`${base}/disputes/${dispute.id}/consent`)
        .set(org.auth)
        .send({ granted: true })
        .expect(200)
        .expect((r) => expect(r.body).toMatchObject({ status: 'consented' }));

      await http().get(evidence).set(org.auth).expect(403);
      const seen = await http().get(evidence).set(officer.auth).expect(200);
      const body = seen.body as { entries: Record<string, unknown>[] };
      expect(body.entries).toEqual([
        {
          reference: mine.reference,
          type: 'contribution_recorded',
          cycleNumber: 1,
          amountMinor: 500_000,
          method: 'cash',
          createdAt: expect.any(String) as string,
          subject: 'Member A',
          recordedBy: 'Member A',
          status: 'corrected',
          hash: expect.stringMatching(/^[0-9a-f]{64}$/) as string,
        },
      ]);
      expect(JSON.stringify(seen.body)).not.toMatch(PRIVATE);
      expect(JSON.stringify(seen.body)).not.toContain(amaya.id);

      const log = await pool.query(
        'SELECT officer_id FROM dispute_access_log WHERE dispute_id = $1',
        [dispute.id],
      );
      expect(log.rows).toEqual([{ officer_id: officer.id }]);
      expect((await inbox(amaya)).items[0].kind).toBe('evidence_viewed');
      const list = await http()
        .get(`${base}/disputes`)
        .set(amaya.auth)
        .expect(200);
      expect(
        (list.body as { disputes: { views: string[] }[] }).disputes[0].views,
      ).toHaveLength(1);

      await http()
        .post(`/community/disputes/${dispute.id}/resolve`)
        .set(officer.auth)
        .send({
          note: 'Bank slip shown to both sides; payment to be re-recorded.',
        })
        .expect(204);
      const done = await http()
        .get(`${base}/disputes`)
        .set(org.auth)
        .expect(200);
      expect((done.body as { disputes: object[] }).disputes[0]).toMatchObject({
        status: 'resolved',
        resolutionNote:
          'Bank slip shown to both sides; payment to be re-recorded.',
      });
    });

    it('a refusal closes the request for good', async () => {
      const circle = await startedCircle([org, amaya, bimal]);
      const mine = await pay(circle.id, amaya, 1);
      const raised = await http()
        .post(`/circles/${circle.id}/disputes`)
        .set(amaya.auth)
        .send({ entryIds: [mine.id], category: 'payment_not_recorded' })
        .expect(201);
      const id = (raised.body as { id: string }).id;
      const consent = `/circles/${circle.id}/disputes/${id}/consent`;
      await http()
        .put(consent)
        .set(org.auth)
        .send({ granted: false })
        .expect(200)
        .expect((r) => expect(r.body).toMatchObject({ status: 'declined' }));
      await http()
        .put(consent)
        .set(org.auth)
        .send({ granted: true })
        .expect(409);
      await http()
        .get(`/community/disputes/${id}/evidence`)
        .set(officer.auth)
        .expect(404);
    });
  });
});
