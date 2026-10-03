import { createHash, randomUUID } from 'node:crypto';
import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { Pool } from 'pg';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from './../src/app.module';
import { configureApp } from './../src/app.setup';
import type {
  CircleDetail,
  CircleSummary,
} from './../src/circles/circles.types';
import {
  addDays,
  dueDateFor,
  localDate,
} from './../src/circles/domain/schedule';
import { CLOCK, Clock } from './../src/common/clock/clock';
import type { LedgerEntry } from './../src/ledger/ledger.types';
import { OTP_SENDER, OtpPurpose, OtpSender } from './../src/otp/otp-sender';
import { createTestDatabase, TestDatabase } from './support/test-db';

class RecordingSender implements OtpSender {
  sent: { purpose: OtpPurpose; target: string; code: string }[] = [];
  send(m: { purpose: OtpPurpose; target: string; code: string }) {
    this.sent.push(m);
    return Promise.resolve();
  }
  last(purpose: OtpPurpose): string {
    const m = [...this.sent].reverse().find((s) => s.purpose === purpose);
    if (!m) throw new Error(`no ${purpose} otp sent`);
    return m.code;
  }
}

class TestClock implements Clock {
  now(): Date {
    return new Date();
  }
}

interface User {
  id: string;
  name: string;
  token: string;
}

interface QueueItem {
  entryId: string;
  reference: string;
  cycleNumber: number;
  subjectUserId: string;
  subjectName: string;
  amountMinor: number;
  method: string;
  provider: string | null;
  receiptReference: string | null;
  recordedAt: string;
  actorName: string;
}

interface ErrorBody {
  statusCode: number;
  code: string;
  message: string;
}

const UNIT = 500_000;
const sha256 = (s: string) => createHash('sha256').update(s).digest('hex');
const HEX64 = /^[0-9a-f]{64}$/;

describe('Circles & ledger (e2e)', () => {
  let db: TestDatabase;
  let app: INestApplication<App>;
  let pool: Pool;
  let sender: RecordingSender;
  const savedUrl = process.env.DATABASE_URL;
  const http = () => request(app.getHttpServer());
  const today = localDate(new Date());
  const firstDue = addDays(today, 20);

  const as = (u: User) => {
    const auth = { Authorization: `Bearer ${u.token}` };
    return {
      get: (p: string) => http().get(p).set(auth),
      post: (p: string, body: object = {}) =>
        http().post(p).set(auth).send(body),
    };
  };

  async function expectError(
    res: Promise<request.Response> | request.Test,
    status: number,
    code: string,
  ): Promise<void> {
    const r = await res;
    expect({ status: r.status, code: (r.body as ErrorBody).code }).toEqual({
      status,
      code,
    });
  }

  let seq = 0;
  async function registerUser(name: string): Promise<User> {
    seq += 1;
    const n = String(seq).padStart(4, '0');
    const phone = `07710${n}0`;
    await http().post('/auth/otp/request').send({ phone }).expect(200);
    const verify = await http()
      .post('/auth/otp/verify')
      .send({ phone, code: sender.last('phone_register') })
      .expect(200);
    const res = await http()
      .post('/auth/register')
      .send({
        fullName: name,
        age: 30,
        nic: `85100${n}V`,
        phone,
        email: `user${n}@circles.e2e.test`,
        password: 'Passw0rdTest',
        phoneVerificationToken: (
          verify.body as { phoneVerificationToken: string }
        ).phoneVerificationToken,
      })
      .expect(201);
    const body = res.body as { accessToken: string; user: { id: string } };
    return { id: body.user.id, name, token: body.accessToken };
  }

  const createBody = (over: Record<string, unknown> = {}) => ({
    name: 'Friends Seettu',
    contributionMinor: UNIT,
    interval: 'monthly',
    turnRule: 'fixed',
    plannedCycles: 3,
    firstDueDate: firstDue,
    ...over,
  });

  async function createCircle(
    u: User,
    over: Record<string, unknown> = {},
  ): Promise<CircleDetail> {
    const res = await as(u).post('/circles', createBody(over)).expect(201);
    return res.body as CircleDetail;
  }

  async function detail(u: User, id: string): Promise<CircleDetail> {
    return (await as(u).get(`/circles/${id}`).expect(200)).body as CircleDetail;
  }

  function record(
    u: User,
    circleId: string,
    over: Record<string, unknown> = {},
  ): request.Test {
    return as(u).post(`/circles/${circleId}/contributions`, {
      cycleNumber: 1,
      method: 'bank_transfer',
      clientEntryId: randomUUID(),
      ...over,
    });
  }

  let org: User;
  let m1: User;
  let m2: User;
  let outsider: User;

  beforeAll(async () => {
    db = await createTestDatabase(savedUrl as string);
    process.env.DATABASE_URL = db.url;
    pool = new Pool({ connectionString: db.url });
    sender = new RecordingSender();
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(OTP_SENDER)
      .useValue(sender)
      .overrideProvider(CLOCK)
      .useValue(new TestClock())
      .compile();
    app = moduleRef.createNestApplication<INestApplication<App>>();
    configureApp(app);
    await app.init();
    org = await registerUser('Kamala Silva');
    m1 = await registerUser('Nimal Perera');
    m2 = await registerUser('Sunil Fernando');
    outsider = await registerUser('Ruwan Outsider');
  }, 60_000);

  afterAll(async () => {
    await app?.close();
    await pool?.end();
    process.env.DATABASE_URL = savedUrl;
    await db?.drop();
  });

  describe('fixed-order circle lifecycle', () => {
    let circle: CircleDetail;
    let m1Entry: LedgerEntry;
    let m2Entry: LedgerEntry;

    it('requires authentication', async () => {
      await expectError(http().get('/circles'), 401, 'UNAUTHORIZED');
    });

    it('validates the create body', async () => {
      const bad: Record<string, unknown>[] = [
        { name: 'A' },
        { name: 'x'.repeat(61) },
        { contributionMinor: 99 },
        { contributionMinor: 100_000_001 },
        { contributionMinor: 1000.5 },
        { contributionMinor: '500000' },
        { interval: 'daily' },
        { turnRule: 'auction' },
        { plannedCycles: 1 },
        { plannedCycles: 61 },
        { firstDueDate: '30/10/2026' },
        { extra: true },
      ];
      for (const over of bad) {
        const res = await as(org).post('/circles', createBody(over));
        expect([over, res.status]).toEqual([over, 400]);
      }
      for (const firstDueDate of [
        addDays(today, -1),
        addDays(today, 366),
        '2026-02-30',
      ]) {
        await expectError(
          as(org).post('/circles', createBody({ firstDueDate })),
          400,
          'INVALID_FIRST_DUE_DATE',
        );
      }
    });

    it('creates a draft circle with the creator as organizer', async () => {
      circle = await createCircle(org);
      expect(circle).toMatchObject({
        name: 'Friends Seettu',
        role: 'organizer',
        status: 'draft',
        contributionMinor: UNIT,
        interval: 'monthly',
        turnRule: 'fixed',
        plannedCycles: 3,
        memberCount: 1,
        firstDueDate: firstDue,
        myTurn: null,
        currentCycle: null,
        current: null,
        cycles: [],
        lottery: {
          commitment: null,
          seed: null,
          committedAt: null,
          revealedAt: null,
        },
        members: [
          {
            userId: org.id,
            displayName: 'Kamala Silva',
            role: 'organizer',
            payoutPosition: null,
            isYou: true,
            joinedCycle: 1,
          },
        ],
      });
      expect(circle.publicCode).toMatch(/^RC-\d{3,}$/);
      expect(circle.joinCode).toMatch(/^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{8}$/);
      const ledger = (
        await as(org).get(`/circles/${circle.id}/ledger?scope=all`).expect(200)
      ).body as { entries: LedgerEntry[] };
      expect(ledger.entries).toHaveLength(1);
      expect(ledger.entries[0]).toMatchObject({
        type: 'member_added',
        subjectUserId: org.id,
        actorUserId: org.id,
        status: null,
      });
    });

    it('joins by code (case/dash-insensitive) and enforces join rules', async () => {
      const code = circle.joinCode as string;
      const messy = ` ${code.slice(0, 4).toLowerCase()}-${code.slice(4)} `;
      const joined = (
        await as(m1).post('/circles/join', { code: messy }).expect(200)
      ).body as CircleDetail;
      expect(joined).toMatchObject({
        id: circle.id,
        role: 'member',
        memberCount: 2,
      });
      expect(joined.members.find((x) => x.isYou)?.userId).toBe(m1.id);

      await expectError(
        as(m1).post('/circles/join', { code }),
        409,
        'ALREADY_MEMBER',
      );
      await expectError(
        as(m2).post('/circles/join', { code: 'ZZZ' }),
        404,
        'INVALID_JOIN_CODE',
      );
      await expectError(
        as(m2).post('/circles/join', {
          code: code === 'AAAAAAAA' ? 'BBBBBBBB' : 'AAAAAAAA',
        }),
        404,
        'INVALID_JOIN_CODE',
      );
      await as(m2).post('/circles/join', { code }).expect(200);
      await expectError(
        as(outsider).post('/circles/join', { code }),
        409,
        'CIRCLE_FULL',
      );
    });

    it('hides the circle from non-members and checks roles', async () => {
      await expectError(
        as(outsider).get(`/circles/${circle.id}`),
        404,
        'CIRCLE_NOT_FOUND',
      );
      await expectError(
        as(outsider).get(`/circles/${randomUUID()}`),
        404,
        'CIRCLE_NOT_FOUND',
      );
      await expectError(
        as(org).get('/circles/not-a-uuid'),
        404,
        'CIRCLE_NOT_FOUND',
      );
      await expectError(
        as(outsider).post(`/circles/${circle.id}/start`, {}),
        404,
        'CIRCLE_NOT_FOUND',
      );
      await expectError(
        as(m1).post(`/circles/${circle.id}/start`, {
          order: [m1.id, org.id, m2.id],
        }),
        403,
        'FORBIDDEN_ROLE',
      );
      await expectError(record(m1, circle.id), 409, 'CIRCLE_NOT_ACTIVE');
    });

    it('rejects an invalid turn order', async () => {
      for (const order of [
        undefined,
        [m1.id, org.id],
        [m1.id, org.id, org.id],
        [m1.id, org.id, outsider.id],
        [m1.id, org.id, m2.id, outsider.id],
        ['nope', org.id, m2.id],
      ]) {
        await expectError(
          as(org).post(`/circles/${circle.id}/start`, order ? { order } : {}),
          400,
          'INVALID_TURN_ORDER',
        );
      }
    });

    it('starts with an explicit order and schedules every cycle', async () => {
      const order = [m1.id, org.id.toUpperCase(), m2.id];
      circle = (
        await as(org).post(`/circles/${circle.id}/start`, { order }).expect(200)
      ).body as CircleDetail;
      expect(circle.status).toBe('active');
      expect(circle.plannedCycles).toBe(3);
      expect(circle.myTurn).toBe(2);
      expect(circle.members.map((x) => [x.userId, x.payoutPosition])).toEqual([
        [m1.id, 1],
        [org.id, 2],
        [m2.id, 3],
      ]);
      expect(circle.cycles).toEqual(
        [m1.id, org.id, m2.id].map((id, i) => ({
          number: i + 1,
          dueDate: dueDateFor(firstDue, 'monthly', i + 1),
          status: 'open',
          recipientUserId: id,
          closedAt: null,
        })),
      );
      expect(circle.currentCycle).toEqual({
        number: 1,
        dueDate: firstDue,
        myStatus: 'due',
        myContribution: null,
        recipient: { userId: m1.id, displayName: 'Nimal Perera', isYou: false },
      });
      expect(circle.current?.members.map((x) => x.status)).toEqual([
        'due',
        'due',
        'due',
      ]);
      expect(circle.current?.totals).toEqual({
        verified: { count: 0, unitMinor: UNIT, totalMinor: 0, entryIds: [] },
        awaiting: { count: 0, unitMinor: UNIT, totalMinor: 0, entryIds: [] },
        unpaid: {
          count: 3,
          userIds: [org.id, m1.id, m2.id].sort(),
        },
        membersDue: 3,
        expectedMinor: 3 * UNIT,
      });
      await expectError(
        as(org).post(`/circles/${circle.id}/start`, { order }),
        409,
        'CIRCLE_ALREADY_STARTED',
      );
      const { rows } = await pool.query<{ payload: Record<string, unknown> }>(
        `SELECT payload FROM ledger_entries WHERE circle_id = $1 AND entry_type = 'turn_order_set'`,
        [circle.id],
      );
      expect(rows).toEqual([
        { payload: { rule: 'fixed', order: [m1.id, org.id, m2.id] } },
      ]);
    });

    it('records a contribution idempotently', async () => {
      const clientEntryId = randomUUID();
      const body = {
        cycleNumber: 1,
        method: 'bank_transfer',
        provider: 'BOC',
        receiptReference: 'TX-778812',
        clientEntryId,
        deviceCreatedAt: new Date().toISOString(),
      };
      const first = await as(m1)
        .post(`/circles/${circle.id}/contributions`, body)
        .expect(201);
      m1Entry = (first.body as { entry: LedgerEntry }).entry;
      expect(m1Entry).toMatchObject({
        type: 'contribution_recorded',
        cycleNumber: 1,
        subjectUserId: m1.id,
        subjectName: 'Nimal Perera',
        actorUserId: m1.id,
        actorName: 'Nimal Perera',
        amountMinor: UNIT,
        method: 'bank_transfer',
        provider: 'BOC',
        receiptReference: 'TX-778812',
        targetEntryId: null,
        note: null,
        status: 'recorded',
      });
      expect(m1Entry.reference).toMatch(/^PS-\d{4,}$/);
      expect(m1Entry.hash).toMatch(HEX64);
      expect(m1Entry.prevHash).toMatch(HEX64);
      expect(Object.keys(m1Entry).sort()).toEqual(
        [
          'id',
          'seq',
          'type',
          'reference',
          'cycleNumber',
          'subjectUserId',
          'subjectName',
          'actorUserId',
          'actorName',
          'amountMinor',
          'method',
          'provider',
          'receiptReference',
          'targetEntryId',
          'note',
          'createdAt',
          'prevHash',
          'hash',
          'status',
        ].sort(),
      );

      const replay = await as(m1)
        .post(`/circles/${circle.id}/contributions`, body)
        .expect(200);
      expect((replay.body as { entry: LedgerEntry }).entry).toEqual(m1Entry);

      await expectError(record(m1, circle.id), 409, 'ALREADY_RECORDED');
      await expectError(
        record(m1, circle.id, { subjectUserId: m2.id }),
        403,
        'FORBIDDEN_ROLE',
      );
      for (const over of [
        { clientEntryId: '6ba7b810-9dad-11d1-80b4-00c04fd430c8' },
        { clientEntryId: 'not-a-uuid' },
        { method: 'paypal' },
        { cycleNumber: 0 },
        { provider: 'x'.repeat(41) },
        { receiptReference: 'x'.repeat(65) },
        { amountMinor: 1 },
      ]) {
        const res = await record(m2, circle.id, over);
        expect([over, res.status]).toEqual([over, 400]);
      }
      await expectError(
        record(m2, circle.id, { cycleNumber: 9 }),
        409,
        'CYCLE_NOT_OPEN',
      );
    });

    it('lets the organizer verify from the queue', async () => {
      await expectError(
        as(m1).get(`/circles/${circle.id}/verify-queue`),
        403,
        'FORBIDDEN_ROLE',
      );
      const queue = (
        await as(org).get(`/circles/${circle.id}/verify-queue`).expect(200)
      ).body as { items: QueueItem[] };
      expect(queue.items).toEqual([
        {
          entryId: m1Entry.id,
          reference: m1Entry.reference,
          cycleNumber: 1,
          subjectUserId: m1.id,
          subjectName: 'Nimal Perera',
          amountMinor: UNIT,
          method: 'bank_transfer',
          provider: 'BOC',
          receiptReference: 'TX-778812',
          recordedAt: m1Entry.createdAt,
          actorName: 'Nimal Perera',
        },
      ]);

      await expectError(
        as(m1).post(`/circles/${circle.id}/contributions/${m1Entry.id}/verify`),
        403,
        'FORBIDDEN_ROLE',
      );
      const verified = (
        await as(org)
          .post(`/circles/${circle.id}/contributions/${m1Entry.id}/verify`)
          .expect(201)
      ).body as { entry: LedgerEntry };
      expect(verified.entry).toMatchObject({
        type: 'contribution_verified',
        targetEntryId: m1Entry.id,
        subjectUserId: m1.id,
        actorUserId: org.id,
        cycleNumber: 1,
        amountMinor: null,
        status: null,
      });
      await expectError(
        as(org).post(
          `/circles/${circle.id}/contributions/${m1Entry.id}/verify`,
        ),
        409,
        'ALREADY_VERIFIED',
      );
      await expectError(
        as(org).post(
          `/circles/${circle.id}/contributions/${m1Entry.id}/reject`,
          {
            reason: 'Not received',
          },
        ),
        409,
        'ALREADY_VERIFIED',
      );
      await expectError(
        as(org).post(
          `/circles/${circle.id}/contributions/${randomUUID()}/verify`,
        ),
        404,
        'ENTRY_NOT_FOUND',
      );
      await expectError(
        as(org).post(
          `/circles/${circle.id}/contributions/${verified.entry.id}/verify`,
        ),
        404,
        'ENTRY_NOT_FOUND',
      );

      const d = await detail(org, circle.id);
      expect(d.current?.members.find((x) => x.userId === m1.id)).toMatchObject({
        status: 'verified',
        contributionEntryId: m1Entry.id,
        reference: m1Entry.reference,
        method: 'bank_transfer',
        recordedAt: m1Entry.createdAt,
        verifiedAt: verified.entry.createdAt,
      });
      expect(d.current?.totals.verified).toEqual({
        count: 1,
        unitMinor: UNIT,
        totalMinor: UNIT,
        entryIds: [m1Entry.id],
      });
      expect(d.current?.totals.unpaid.count).toBe(2);

      const list = (await as(m1).get('/circles').expect(200)).body as {
        circles: CircleSummary[];
      };
      const mine = list.circles.find((c) => c.id === circle.id);
      expect(mine?.currentCycle).toMatchObject({
        myStatus: 'verified',
        myContribution: {
          entryId: m1Entry.id,
          reference: m1Entry.reference,
          method: 'bank_transfer',
          recordedAt: m1Entry.createdAt,
          verifiedAt: verified.entry.createdAt,
        },
        recipient: { userId: m1.id, isYou: true },
      });
      expect(mine).not.toHaveProperty('members');
    });

    it('rejection returns the member to due so they can record again', async () => {
      m2Entry = (
        (await record(m2, circle.id, { method: 'lankaqr' }).expect(201))
          .body as { entry: LedgerEntry }
      ).entry;
      await as(org)
        .post(`/circles/${circle.id}/contributions/${m2Entry.id}/reject`, {
          reason: 'x',
        })
        .expect(400);
      const rejected = (
        await as(org)
          .post(`/circles/${circle.id}/contributions/${m2Entry.id}/reject`, {
            reason: 'Not received in account',
          })
          .expect(201)
      ).body as { entry: LedgerEntry };
      expect(rejected.entry).toMatchObject({
        type: 'correction',
        targetEntryId: m2Entry.id,
        subjectUserId: m2.id,
        amountMinor: -UNIT,
        note: 'Not received in account',
        status: null,
      });
      await expectError(
        as(org).post(
          `/circles/${circle.id}/contributions/${m2Entry.id}/reject`,
          {
            reason: 'again',
          },
        ),
        409,
        'ENTRY_CORRECTED',
      );
      await expectError(
        as(org).post(
          `/circles/${circle.id}/contributions/${m2Entry.id}/verify`,
        ),
        409,
        'ENTRY_CORRECTED',
      );

      let d = await detail(m2, circle.id);
      expect(d.currentCycle?.myStatus).toBe('due');
      expect(d.currentCycle?.myContribution).toBeNull();

      const again = (
        (await record(m2, circle.id, { method: 'cash' }).expect(201)).body as {
          entry: LedgerEntry;
        }
      ).entry;
      d = await detail(m2, circle.id);
      expect(d.currentCycle?.myStatus).toBe('recorded');
      expect(d.current?.totals.awaiting).toEqual({
        count: 1,
        unitMinor: UNIT,
        totalMinor: UNIT,
        entryIds: [again.id],
      });

      const mine = (
        await as(m2).get(`/circles/${circle.id}/ledger?scope=mine`).expect(200)
      ).body as { entries: LedgerEntry[] };
      expect(mine.entries.map((e) => [e.type, e.status])).toEqual([
        ['contribution_recorded', 'recorded'],
        ['correction', null],
        ['contribution_recorded', 'corrected'],
        ['member_added', null],
      ]);
      m2Entry = again;
    });

    it('closes a cycle only when verified and acknowledged', async () => {
      const close = (u: User, n: number, acknowledgeUnpaid: number) =>
        as(u).post(`/circles/${circle.id}/cycles/${n}/close`, {
          acknowledgeUnpaid,
        });
      await expectError(close(m1, 1, 1), 403, 'FORBIDDEN_ROLE');
      await expectError(close(org, 1, 1), 409, 'PENDING_VERIFICATIONS');
      await as(org)
        .post(`/circles/${circle.id}/contributions/${m2Entry.id}/verify`)
        .expect(201);
      await expectError(close(org, 1, 0), 409, 'UNPAID_NOT_ACKNOWLEDGED');
      await expectError(close(org, 2, 1), 409, 'CYCLE_NOT_OPEN');
      await expectError(close(org, 9, 1), 409, 'CYCLE_NOT_OPEN');

      const before = await detail(org, circle.id);
      expect(before.current?.totals.verified.totalMinor).toBe(2 * UNIT);
      const after = (await close(org, 1, 1).expect(200)).body as CircleDetail;
      expect(after.cycles[0].status).toBe('closed');
      expect(after.cycles[0].closedAt).not.toBeNull();
      expect(after.status).toBe('active');
      expect(after.currentCycle).toMatchObject({
        number: 2,
        dueDate: dueDateFor(firstDue, 'monthly', 2),
        myStatus: 'due',
        recipient: { userId: org.id, isYou: true },
      });
      await expectError(close(org, 1, 1), 409, 'CYCLE_NOT_OPEN');

      const all = (
        await as(org).get(`/circles/${circle.id}/ledger?scope=all`).expect(200)
      ).body as { entries: LedgerEntry[] };
      const seqs = all.entries.map((e) => e.seq);
      expect(seqs).toEqual([...seqs].sort((a, b) => b - a));
      expect(all.entries[0]).toMatchObject({
        type: 'cycle_closed',
        cycleNumber: 1,
      });
      expect(all.entries[1]).toMatchObject({
        type: 'payout',
        cycleNumber: 1,
        subjectUserId: m1.id,
        amountMinor: before.current?.totals.verified.totalMinor,
      });
      await expectError(
        record(m1, circle.id, { cycleNumber: 1 }),
        409,
        'CYCLE_NOT_OPEN',
      );
    });

    it('lets the organizer record cash for a member, not members for others', async () => {
      const res = await record(org, circle.id, {
        cycleNumber: 2,
        method: 'cash',
        subjectUserId: m1.id,
      }).expect(201);
      expect((res.body as { entry: LedgerEntry }).entry).toMatchObject({
        subjectUserId: m1.id,
        actorUserId: org.id,
        actorName: 'Kamala Silva',
        method: 'cash',
        cycleNumber: 2,
      });
      await expectError(
        record(m2, circle.id, { cycleNumber: 2, subjectUserId: org.id }),
        403,
        'FORBIDDEN_ROLE',
      );
      await expectError(
        record(org, circle.id, {
          cycleNumber: 2,
          subjectUserId: outsider.id,
        }),
        404,
        'MEMBER_NOT_FOUND',
      );
    });

    it('scopes the ledger', async () => {
      const mine = (
        await as(m1).get(`/circles/${circle.id}/ledger?scope=mine`).expect(200)
      ).body as { entries: LedgerEntry[] };
      expect(mine.entries.length).toBeGreaterThan(0);
      const ids = new Set(
        mine.entries.filter((e) => e.subjectUserId === m1.id).map((e) => e.id),
      );
      for (const e of mine.entries) {
        expect(
          e.subjectUserId === m1.id || ids.has(e.targetEntryId ?? ''),
        ).toBe(true);
      }
      expect(mine.entries.map((e) => e.type)).toContain('payout');
      const defaultScope = (
        await as(m1).get(`/circles/${circle.id}/ledger`).expect(200)
      ).body as { entries: LedgerEntry[] };
      expect(defaultScope).toEqual(mine);
      await expectError(
        as(m1).get(`/circles/${circle.id}/ledger?scope=all`),
        403,
        'FORBIDDEN_ROLE',
      );
      await as(m1).get(`/circles/${circle.id}/ledger?scope=other`).expect(400);
      await expectError(
        as(outsider).get(`/circles/${circle.id}/ledger`),
        404,
        'CIRCLE_NOT_FOUND',
      );
    });

    it('the ledger is append-only and hash-chained', async () => {
      await expect(
        pool.query(
          `UPDATE ledger_entries SET note = 'tampered' WHERE circle_id = $1`,
          [circle.id],
        ),
      ).rejects.toThrow(/append-only/);
      await expect(
        pool.query(`DELETE FROM ledger_entries WHERE circle_id = $1`, [
          circle.id,
        ]),
      ).rejects.toThrow(/append-only/);

      const { rows } = await pool.query<Record<string, string | null>>(
        `SELECT id::text, circle_id::text, cycle_id::text, subject_user_id::text,
                actor_user_id::text, entry_type::text, amount_minor::text, method::text,
                reference, target_entry_id::text,
                to_char(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS ts,
                payload::text AS payload, method_provider, receipt_reference, prev_hash, hash
         FROM ledger_entries WHERE circle_id = $1 ORDER BY seq`,
        [circle.id],
      );
      expect(rows.length).toBeGreaterThan(8);
      let prev = '0'.repeat(64);
      for (const r of rows) {
        expect(r.prev_hash).toBe(prev);
        const parts = [
          r.prev_hash,
          r.id,
          r.circle_id,
          r.cycle_id,
          r.subject_user_id,
          r.actor_user_id,
          r.entry_type,
          r.amount_minor,
          r.method,
          r.reference,
          r.target_entry_id,
          r.ts,
          r.payload,
          r.method_provider,
          r.receipt_reference,
        ].filter((v) => v !== null);
        expect(r.hash).toBe(sha256(parts.join('|')));
        prev = r.hash as string;
      }
    });
  });

  describe('lottery circle', () => {
    let circle: CircleDetail;

    it('commits, hides the seed, then reveals it on start', async () => {
      circle = await createCircle(org, {
        name: 'Office Lottery',
        turnRule: 'lottery',
        interval: 'weekly',
        plannedCycles: 4,
      });
      await as(m1).post('/circles/join', { code: circle.joinCode }).expect(200);
      await expectError(
        as(org).post(`/circles/${circle.id}/start`, {}),
        409,
        'LOTTERY_NOT_COMMITTED',
      );
      await expectError(
        as(m1).post(`/circles/${circle.id}/lottery/commit`),
        403,
        'FORBIDDEN_ROLE',
      );
      const first = (
        await as(org).post(`/circles/${circle.id}/lottery/commit`).expect(200)
      ).body as CircleDetail;
      expect(first.lottery.commitment).toMatch(HEX64);
      expect(first.lottery.seed).toBeNull();
      expect(first.lottery.committedAt).not.toBeNull();
      expect(first.lottery.revealedAt).toBeNull();
      const second = (
        await as(org).post(`/circles/${circle.id}/lottery/commit`).expect(200)
      ).body as CircleDetail;
      expect(second.lottery.commitment).not.toBe(first.lottery.commitment);
      const seen = await detail(m1, circle.id);
      expect(seen.lottery.commitment).toBe(second.lottery.commitment);
      expect(seen.lottery.seed).toBeNull();

      await as(m2).post('/circles/join', { code: circle.joinCode }).expect(200);
      const started = (
        await as(org)
          .post(`/circles/${circle.id}/start`, { order: [m2.id] })
          .expect(200)
      ).body as CircleDetail;
      const seed = started.lottery.seed as string;
      expect(seed).toMatch(HEX64);
      expect(sha256(seed)).toBe(second.lottery.commitment);
      expect(started.lottery.revealedAt).not.toBeNull();
      expect(started.plannedCycles).toBe(3);
      const expected = [org.id, m1.id, m2.id]
        .map((id) => ({ id, key: sha256(`${seed}:${id}`) }))
        .sort((a, b) => (a.key < b.key ? -1 : 1))
        .map((x) => x.id);
      expect(started.members.map((x) => x.userId)).toEqual(expected);
      expect(started.members.map((x) => x.payoutPosition)).toEqual([1, 2, 3]);
      expect(started.cycles.map((c) => [c.recipientUserId, c.dueDate])).toEqual(
        expected.map((id, i) => [id, dueDateFor(firstDue, 'weekly', i + 1)]),
      );
      const { rows } = await pool.query<{ payload: Record<string, unknown> }>(
        `SELECT payload FROM ledger_entries WHERE circle_id = $1 AND entry_type = 'turn_order_set'`,
        [circle.id],
      );
      expect(rows[0].payload).toEqual({
        rule: 'lottery',
        order: expected,
        seed,
        commitment: second.lottery.commitment,
      });

      await expectError(
        as(outsider).post('/circles/join', { code: circle.joinCode }),
        409,
        'CIRCLE_ALREADY_STARTED',
      );
      await expectError(
        as(org).post(`/circles/${circle.id}/lottery/commit`),
        409,
        'CIRCLE_ALREADY_STARTED',
      );
    });
  });

  describe('small circle: concurrency and completion', () => {
    let circle: CircleDetail;

    it('guards draft-only actions', async () => {
      circle = await createCircle(org, {
        name: 'Pair',
        interval: 'fortnightly',
        plannedCycles: 2,
      });
      await expectError(
        as(org).post(`/circles/${circle.id}/start`, { order: [org.id] }),
        409,
        'NOT_ENOUGH_MEMBERS',
      );
      await expectError(
        as(org).post(`/circles/${circle.id}/lottery/commit`),
        409,
        'WRONG_TURN_RULE',
      );
    });

    it('serialises simultaneous joins and records', async () => {
      const joins = await Promise.all(
        [1, 2, 3].map(() =>
          as(m1).post('/circles/join', { code: circle.joinCode }),
        ),
      );
      expect(joins.map((r) => r.status).sort()).toEqual([200, 409, 409]);
      await as(org)
        .post(`/circles/${circle.id}/start`, { order: [org.id, m1.id] })
        .expect(200);

      const records = await Promise.all(
        [1, 2, 3].map(() => record(m1, circle.id)),
      );
      expect(records.map((r) => r.status).sort()).toEqual([201, 409, 409]);

      const clientEntryId = randomUUID();
      const replays = await Promise.all(
        [1, 2, 3].map(() => record(org, circle.id, { clientEntryId })),
      );
      expect(replays.map((r) => r.status).sort()).toEqual([200, 200, 201]);
      const ids = new Set(
        replays.map((r) => (r.body as { entry: LedgerEntry }).entry.id),
      );
      expect(ids.size).toBe(1);

      const queue = (
        await as(org).get(`/circles/${circle.id}/verify-queue`).expect(200)
      ).body as { items: QueueItem[] };
      expect(queue.items.map((i) => i.subjectUserId)).toEqual([m1.id, org.id]);
      const verifies = await Promise.all(
        [1, 2].map(() =>
          as(org).post(
            `/circles/${circle.id}/contributions/${queue.items[0].entryId}/verify`,
          ),
        ),
      );
      expect(verifies.map((r) => r.status).sort()).toEqual([201, 409]);
      await as(org)
        .post(
          `/circles/${circle.id}/contributions/${queue.items[1].entryId}/verify`,
        )
        .expect(201);

      const closes = await Promise.all(
        [1, 2].map(() =>
          as(org).post(`/circles/${circle.id}/cycles/1/close`, {
            acknowledgeUnpaid: 0,
          }),
        ),
      );
      expect(closes.map((r) => r.status).sort()).toEqual([200, 409]);
    });

    it('completes after the last cycle and sorts the list', async () => {
      const done = (
        await as(org)
          .post(`/circles/${circle.id}/cycles/2/close`, {
            acknowledgeUnpaid: 2,
          })
          .expect(200)
      ).body as CircleDetail;
      expect(done.status).toBe('completed');
      expect(done.current).toBeNull();
      expect(done.currentCycle).toBeNull();
      expect(done.cycles.every((c) => c.status === 'closed')).toBe(true);
      const { rows } = await pool.query<{ amount_minor: string | null }>(
        `SELECT e.amount_minor FROM ledger_entries e JOIN cycles c ON c.id = e.cycle_id
         WHERE e.circle_id = $1 AND e.entry_type = 'payout' ORDER BY c.number`,
        [circle.id],
      );
      expect(rows.map((r) => r.amount_minor)).toEqual([String(2 * UNIT), null]);

      const draft = await createCircle(org, { name: 'Next Year' });
      const list = (await as(org).get('/circles').expect(200)).body as {
        circles: CircleSummary[];
      };
      const rank = { active: 0, draft: 1, completed: 2 };
      const ranks = list.circles.map((c) => rank[c.status]);
      expect(ranks).toEqual([...ranks].sort());
      expect(list.circles.map((c) => c.id)).toEqual(
        expect.arrayContaining([circle.id, draft.id]),
      );
      expect(list.circles.at(-1)?.id).toBe(circle.id);
      expect(
        (await as(outsider).get('/circles').expect(200)).body as {
          circles: CircleSummary[];
        },
      ).toEqual({ circles: [] });
    });
  });
});
