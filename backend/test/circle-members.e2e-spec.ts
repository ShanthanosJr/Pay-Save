import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import request from 'supertest';
import { App } from 'supertest/types';
import { localDate, addDays } from '../src/circles/domain/schedule';
import { RecordingSender, createTestApp } from './support/app';
import { TestDatabase, createTestDatabase } from './support/test-db';

interface User {
  id: string;
  name: string;
  auth: { Authorization: string };
}

interface Detail {
  id: string;
  status: string;
  collectionMode: string;
  members: {
    userId: string;
    payout: { ready: boolean; kinds: string[] };
  }[];
  myPayout: { id: string; kind: string; summary: string; preferred: boolean }[];
  setup: {
    seatsTotal: number;
    seatsTaken: number;
    pendingInvitations: number;
    membersMissingPayout: string[];
    canStart: boolean;
  };
  invitations: { id: string; person: { id: string } }[];
}

interface Method {
  id: string;
  kind: string;
  summary: string;
  isDefault: boolean;
  details: Record<string, unknown>;
}

const BANK = {
  kind: 'bank_transfer',
  bankName: 'Bank of Ceylon',
  branch: 'Kandy',
  accountName: 'Kamala Silva',
  accountNumber: '0071 2345 6789',
};

describe('Circle members: invitations and payout details (e2e)', () => {
  let db: TestDatabase;
  let app: INestApplication<App>;
  let sender: RecordingSender;
  let pool: Pool;
  const savedUrl = process.env.DATABASE_URL;
  const http = () => request(app.getHttpServer());
  let seq = 0;

  let org: User;
  let amaya: User;
  let bimal: User;
  let stranger: User;

  async function register(name: string): Promise<User> {
    seq += 1;
    const n = String(seq).padStart(2, '0');
    const phone = `07722000${n}`;
    await http().post('/auth/otp/request').send({ phone }).expect(200);
    const v = await http()
      .post('/auth/otp/verify')
      .send({ phone, code: sender.last('phone_register') })
      .expect(200);
    const res = await http()
      .post('/auth/register')
      .send({
        fullName: name,
        age: 30,
        nic: `8810000${n}V`,
        phone,
        email: `m${n}@members.e2e.test`,
        password: 'Passw0rdTest',
        phoneVerificationToken: (v.body as { phoneVerificationToken: string })
          .phoneVerificationToken,
      })
      .expect(201);
    const b = res.body as { accessToken: string; user: { id: string } };
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

  const addMethod = async (u: User, body: object) =>
    (
      (
        await http()
          .post('/users/me/payout-methods')
          .set(u.auth)
          .send(body)
          .expect(201)
      ).body as { methods: Method[] }
    ).methods;

  const createCircle = async (u: User, over: object = {}) =>
    (
      await http()
        .post('/circles')
        .set(u.auth)
        .send({
          name: 'Office Seettu',
          contributionMinor: 500_000,
          interval: 'monthly',
          turnRule: 'fixed',
          plannedCycles: 3,
          firstDueDate: addDays(localDate(new Date()), 10),
          ...over,
        })
        .expect(201)
    ).body as Detail;

  const invitationFor = async (u: User) =>
    (
      (await http().get('/circle-invitations').set(u.auth).expect(200))
        .body as {
        invitations: {
          id: string;
          circle: Record<string, unknown>;
          organizer: { id: string };
        }[];
      }
    ).invitations;

  beforeAll(async () => {
    db = await createTestDatabase(savedUrl as string);
    process.env.DATABASE_URL = db.url;
    pool = new Pool({ connectionString: db.url });
    ({ app, sender } = await createTestApp());
    org = await register('Kamala Silva');
    amaya = await register('Amaya Perera');
    bimal = await register('Bimal Fernando');
    stranger = await register('Ruwan Stranger');
    await makePals(org, amaya);
    await makePals(org, bimal);
    await makePals(amaya, bimal);
  }, 60_000);

  afterAll(async () => {
    await app?.close();
    await pool?.end();
    process.env.DATABASE_URL = savedUrl;
    await db?.drop();
  });

  describe('my payment details', () => {
    it('validates, encrypts at rest, masks summaries and makes the first one default', async () => {
      await http()
        .post('/users/me/payout-methods')
        .set(org.auth)
        .send({ ...BANK, accountNumber: '12ab' })
        .expect(400);
      await http()
        .post('/users/me/payout-methods')
        .set(org.auth)
        .send({ kind: 'cheque' })
        .expect(400);

      const methods = await addMethod(org, BANK);
      expect(methods).toHaveLength(1);
      expect(methods[0]).toMatchObject({
        kind: 'bank_transfer',
        summary: 'Bank of Ceylon · ••••6789',
        isDefault: true,
        details: { accountNumber: '007123456789', accountName: 'Kamala Silva' },
      });

      const raw = await pool.query<{
        details_encrypted: Buffer;
        summary: string;
      }>(
        'SELECT details_encrypted, summary FROM payout_methods WHERE user_id = $1',
        [org.id],
      );
      expect(raw.rows[0].details_encrypted.toString('latin1')).not.toContain(
        '6789',
      );

      const two = await addMethod(org, {
        kind: 'mobile_wallet',
        provider: 'eZ Cash',
        accountName: 'Kamala',
        number: '0771234567',
        makeDefault: true,
      });
      expect(two.find((m) => m.isDefault)?.kind).toBe('mobile_wallet');
      await http()
        .post(`/users/me/payout-methods/${methods[0].id}/default`)
        .set(org.auth)
        .expect(200);

      await addMethod(amaya, { kind: 'cash', note: 'At the Sunday dansala' });
      await addMethod(bimal, {
        kind: 'lankaqr',
        merchantName: 'Bimal Stores',
        reference: '0712345678',
      });
      // someone else's method id cannot be touched
      await http()
        .delete(`/users/me/payout-methods/${methods[0].id}`)
        .set(amaya.auth)
        .expect(404);
    });
  });

  describe('inviting pals', () => {
    let circle: Detail;
    let invitationId: string;

    it('creator shares their default method automatically', async () => {
      circle = await createCircle(org);
      expect(circle.myPayout).toEqual([
        expect.objectContaining({ kind: 'bank_transfer', preferred: true }),
      ]);
      expect(circle.setup).toMatchObject({
        seatsTotal: 3,
        seatsTaken: 1,
        canStart: false,
      });
    });

    it('lists pals with their state and only lets the organizer invite pals', async () => {
      const list = (
        await http()
          .get(`/circles/${circle.id}/invitable-pals`)
          .set(org.auth)
          .expect(200)
      ).body as { seatsLeft: number; pals: { id: string; state: string }[] };
      expect(list.seatsLeft).toBe(2);
      expect(list.pals.map((p) => p.id).sort()).toEqual(
        [amaya.id, bimal.id].sort(),
      );

      const notPal = await http()
        .post(`/circles/${circle.id}/invitations`)
        .set(org.auth)
        .send({ userIds: [stranger.id] })
        .expect(403);
      expect(notPal.body).toMatchObject({
        code: 'NOT_A_PAL',
        userIds: [stranger.id],
      });

      const d = (
        await http()
          .post(`/circles/${circle.id}/invitations`)
          .set(org.auth)
          .send({ userIds: [amaya.id, bimal.id], message: 'Join us for 2027!' })
          .expect(201)
      ).body as Detail;
      expect(d.setup.pendingInvitations).toBe(2);
      expect(d.invitations.map((i) => i.person.id).sort()).toEqual(
        [amaya.id, bimal.id].sort(),
      );

      // re-inviting is harmless; seats are held by pending invitations
      await http()
        .post(`/circles/${circle.id}/invitations`)
        .set(org.auth)
        .send({ userIds: [amaya.id] })
        .expect(201);
      await makePals(org, stranger);
      const full = await http()
        .post(`/circles/${circle.id}/invitations`)
        .set(org.auth)
        .send({ userIds: [stranger.id] })
        .expect(409);
      expect(full.body).toMatchObject({
        code: 'NOT_ENOUGH_SEATS',
        seatsLeft: 0,
      });
    });

    it('the invitee sees the terms, the pot arithmetic and pals inside', async () => {
      const mine = await invitationFor(amaya);
      expect(mine).toHaveLength(1);
      invitationId = mine[0].id;
      expect(mine[0]).toMatchObject({
        message: 'Join us for 2027!',
        organizer: { id: org.id },
        circle: {
          id: circle.id,
          name: 'Office Seettu',
          contributionMinor: 500_000,
          memberCount: 1,
          seatsLeft: 2,
          collectionMode: 'direct_to_recipient',
          payout: { count: 3, unitMinor: 500_000, totalMinor: 1_500_000 },
          palsInside: ['Kamala Silva'],
        },
      });
      expect(await invitationFor(stranger)).toEqual([]);
      await http()
        .post(`/circle-invitations/${invitationId}/accept`)
        .set(bimal.auth)
        .send({})
        .expect(404);
      await http()
        .post(`/circles/${circle.id}/invitations`)
        .set(amaya.auth)
        .send({ userIds: [bimal.id] })
        .expect(404); // not a member yet
    });

    it('accepting joins the circle, shares chosen details and writes the ledger', async () => {
      const amayaMethods = (
        (await http().get('/users/me/payout-methods').set(amaya.auth)).body as {
          methods: Method[];
        }
      ).methods;
      const d = (
        await http()
          .post(`/circle-invitations/${invitationId}/accept`)
          .set(amaya.auth)
          .send({ methodIds: [amayaMethods[0].id] })
          .expect(200)
      ).body as Detail;
      expect(d.setup).toMatchObject({ seatsTaken: 2, pendingInvitations: 1 });
      expect(d.myPayout).toEqual([
        expect.objectContaining({ kind: 'cash', preferred: true }),
      ]);
      expect(d.invitations).toEqual([]); // members never see the invite list
      expect(d.members.find((x) => x.userId === amaya.id)?.payout).toEqual({
        ready: true,
        kinds: ['cash'],
      });

      const ledger = await pool.query<{ payload: Record<string, unknown> }>(
        `SELECT payload FROM ledger_entries
         WHERE circle_id = $1 AND entry_type = 'member_added' AND subject_user_id = $2`,
        [circle.id, amaya.id],
      );
      expect(ledger.rows[0].payload).toMatchObject({
        via: 'invitation',
        invitationId,
      });
      await http()
        .post(`/circle-invitations/${invitationId}/accept`)
        .set(amaya.auth)
        .send({})
        .expect(404);
    });

    it('members see payout readiness as kinds only, never details', async () => {
      const d = (
        await http().get(`/circles/${circle.id}`).set(amaya.auth).expect(200)
      ).body as Detail;
      const json = JSON.stringify(d);
      expect(json).not.toContain('6789');
      expect(json).not.toContain('Bank of Ceylon');
      expect(d.members.find((x) => x.userId === org.id)?.payout).toEqual({
        ready: true,
        kinds: ['bank_transfer'],
      });
    });

    it('starting needs everyone to have payment details; pending invites are cancelled', async () => {
      // Bimal joins by accepting without choosing: his default is shared.
      const [inv] = await invitationFor(bimal);
      await pool.query(
        `UPDATE payout_methods SET archived_at = now(), is_default = false WHERE user_id = $1`,
        [bimal.id],
      );
      await http()
        .post(`/circle-invitations/${inv.id}/accept`)
        .set(bimal.auth)
        .send({})
        .expect(200);

      const blocked = await http()
        .post(`/circles/${circle.id}/start`)
        .set(org.auth)
        .send({ order: [org.id, amaya.id, bimal.id] })
        .expect(409);
      expect(blocked.body).toMatchObject({
        code: 'PAYOUT_DETAILS_MISSING',
        userIds: [bimal.id],
      });

      const methods = await addMethod(bimal, { kind: 'cash' });
      const shared = (
        await http()
          .put(`/circles/${circle.id}/payout-methods`)
          .set(bimal.auth)
          .send({ methodIds: [methods[0].id], preferredId: methods[0].id })
          .expect(200)
      ).body as Detail;
      expect(shared.setup.canStart).toBe(true);

      await http()
        .post(`/circles/${circle.id}/start`)
        .set(org.auth)
        .send({ order: [org.id, amaya.id, bimal.id] })
        .expect(200);
    });

    it('cannot remove the only method a running circle relies on', async () => {
      const methods = (
        (await http().get('/users/me/payout-methods').set(amaya.auth)).body as {
          methods: Method[];
        }
      ).methods;
      const res = await http()
        .delete(`/users/me/payout-methods/${methods[0].id}`)
        .set(amaya.auth)
        .expect(409);
      expect(res.body).toMatchObject({
        code: 'PAYOUT_METHOD_IN_USE',
        circles: ['Office Seettu'],
      });
    });

    it('pay-to (direct): members get the recipient’s full details; each reveal is logged', async () => {
      const payTo = (
        await http()
          .get(`/circles/${circle.id}/pay-to`)
          .set(amaya.auth)
          .expect(200)
      ).body as {
        youReceive: boolean;
        payee: { id: string };
        amount: { totalMinor: number };
        reference: string;
        methods: Method[];
      };
      expect(payTo).toMatchObject({
        youReceive: false,
        payee: { id: org.id },
        amount: { count: 1, unitMinor: 500_000, totalMinor: 500_000 },
      });
      expect(payTo.reference).toMatch(/^RC-\d+ C1 Amaya$/);
      expect(payTo.methods[0].details).toMatchObject({
        accountNumber: '007123456789',
        accountName: 'Kamala Silva',
      });

      const log = await pool.query(
        'SELECT viewer_id, owner_id FROM payout_detail_access_log WHERE circle_id = $1',
        [circle.id],
      );
      expect(log.rows).toEqual([{ viewer_id: amaya.id, owner_id: org.id }]);

      const own = (
        await http()
          .get(`/circles/${circle.id}/pay-to`)
          .set(org.auth)
          .expect(200)
      ).body as { youReceive: boolean; methods: unknown[] };
      expect(own).toMatchObject({ youReceive: true, methods: [] });

      await http()
        .get(`/circles/${circle.id}/pay-to`)
        .set(stranger.auth)
        .expect(404);
    });
  });

  describe('collection via the organizer', () => {
    it('members pay the organizer; the organizer pays the recipient the verified pot', async () => {
      const c = await createCircle(org, {
        name: 'Temple Seettu',
        plannedCycles: 2,
        collectionMode: 'via_organizer',
      });
      expect(c.collectionMode).toBe('via_organizer');
      await http()
        .patch(`/circles/${c.id}`)
        .set(org.auth)
        .send({ collectionMode: 'nonsense' })
        .expect(400);

      await http()
        .post(`/circles/${c.id}/invitations`)
        .set(org.auth)
        .send({ userIds: [amaya.id] })
        .expect(201);
      const [inv] = await invitationFor(amaya);
      await http()
        .post(`/circle-invitations/${inv.id}/accept`)
        .set(amaya.auth)
        .send({})
        .expect(200);
      await http()
        .post(`/circles/${c.id}/start`)
        .set(org.auth)
        .send({ order: [amaya.id, org.id] })
        .expect(200);
      await http()
        .patch(`/circles/${c.id}`)
        .set(org.auth)
        .send({ collectionMode: 'direct_to_recipient' })
        .expect(409);

      const memberView = (
        await http().get(`/circles/${c.id}/pay-to`).set(amaya.auth).expect(200)
      ).body as { payee: { id: string }; youReceive: boolean };
      // Amaya receives cycle 1, but still pays her share to the organizer.
      expect(memberView).toMatchObject({
        payee: { id: org.id },
        youReceive: false,
      });

      const organizerView = (
        await http().get(`/circles/${c.id}/pay-to`).set(org.auth).expect(200)
      ).body as {
        payee: { id: string };
        amount: { count: number; totalMinor: number };
        methods: Method[];
      };
      expect(organizerView.payee.id).toBe(amaya.id);
      expect(organizerView.amount).toMatchObject({ count: 0, totalMinor: 0 });
      expect(organizerView.methods[0].details).toMatchObject({
        kind: 'cash',
        note: 'At the Sunday dansala',
      });
    });
  });

  it('declining removes the invitation; organizers can cancel theirs', async () => {
    const c = await createCircle(org, { name: 'Family Seettu' });
    await http()
      .post(`/circles/${c.id}/invitations`)
      .set(org.auth)
      .send({ userIds: [amaya.id, bimal.id] })
      .expect(201);
    const [a] = await invitationFor(amaya);
    await http()
      .post(`/circle-invitations/${a.id}/decline`)
      .set(amaya.auth)
      .expect(204);
    expect(await invitationFor(amaya)).toEqual([]);

    const d = (await http().get(`/circles/${c.id}`).set(org.auth).expect(200))
      .body as Detail;
    expect(d.invitations).toHaveLength(1);
    await http()
      .delete(`/circles/${c.id}/invitations/${d.invitations[0].id}`)
      .set(org.auth)
      .expect(200);
    expect(await invitationFor(bimal)).toEqual([]);
  });
});
