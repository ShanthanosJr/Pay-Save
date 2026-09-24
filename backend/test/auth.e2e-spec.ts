import { spawnSync } from 'node:child_process';
import { join } from 'node:path';
import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { Pool } from 'pg';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from './../src/app.module';
import { configureApp } from './../src/app.setup';
import { CLOCK, Clock } from './../src/common/clock/clock';
import { OTP_SENDER, OtpPurpose, OtpSender } from './../src/otp/otp-sender';

class RecordingSender implements OtpSender {
  sent: { purpose: OtpPurpose; target: string; code: string }[] = [];
  send(m: {
    purpose: OtpPurpose;
    target: string;
    code: string;
  }): Promise<void> {
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
  offsetMs = 0;
  now(): Date {
    return new Date(Date.now() + this.offsetMs);
  }
}

const PASSWORD = 'Passw0rdTest';
const PHONE = '0770000001';
const PHONE_E164 = '+94770000001';
const EMAIL = 'kasun@e2e.test';
const NIC = '853202345V';

interface Ctx {
  app: INestApplication<App>;
  sender: RecordingSender;
  clock: TestClock;
}

async function createApp(env: Record<string, string> = {}): Promise<Ctx> {
  const saved: Record<string, string | undefined> = {};
  for (const [k, v] of Object.entries(env)) {
    saved[k] = process.env[k];
    process.env[k] = v;
  }
  const sender = new RecordingSender();
  const clock = new TestClock();
  try {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(OTP_SENDER)
      .useValue(sender)
      .overrideProvider(CLOCK)
      .useValue(clock)
      .compile();
    const app = moduleRef.createNestApplication<INestApplication<App>>();
    configureApp(app);
    await app.init();
    return { app, sender, clock };
  } finally {
    for (const [k, v] of Object.entries(saved)) {
      if (v === undefined) delete process.env[k];
      else process.env[k] = v;
    }
  }
}

describe('Auth (e2e)', () => {
  let ctx: Ctx;
  let pool: Pool;
  const http = () => request(ctx.app.getHttpServer());

  beforeAll(() => {
    pool = new Pool({ connectionString: process.env.DATABASE_URL });
  });
  afterAll(async () => {
    await pool.end();
  });

  beforeEach(async () => {
    await pool.query('DELETE FROM otp_challenges');
    await pool.query("DELETE FROM users WHERE email LIKE '%@e2e.test'");
    ctx = await createApp();
  });
  afterEach(async () => {
    await ctx.app.close();
  });

  async function verifiedToken(phone = PHONE): Promise<string> {
    await http().post('/auth/otp/request').send({ phone }).expect(200);
    const code = ctx.sender.last('phone_register');
    const res = await http()
      .post('/auth/otp/verify')
      .send({ phone, code })
      .expect(200);
    return (res.body as { phoneVerificationToken: string })
      .phoneVerificationToken;
  }

  const registerBody = (token: string, over: Record<string, unknown> = {}) => ({
    fullName: 'Kasun Perera',
    age: 34,
    nic: NIC,
    phone: PHONE,
    email: EMAIL,
    password: PASSWORD,
    phoneVerificationToken: token,
    ...over,
  });

  async function register(over: Record<string, unknown> = {}, phone = PHONE) {
    const token = await verifiedToken(phone);
    const res = await http()
      .post('/auth/register')
      .send(registerBody(token, { phone, ...over }));
    return res;
  }

  describe('happy path', () => {
    it('otp -> register -> me -> logout -> logins -> refresh rotation', async () => {
      const otp = await http()
        .post('/auth/otp/request')
        .send({ phone: PHONE })
        .expect(200);
      expect(otp.body).toEqual({
        expiresInSeconds: 300,
        resendAfterSeconds: 30,
      });
      expect(ctx.sender.sent).toHaveLength(1);
      expect(ctx.sender.sent[0]).toMatchObject({
        purpose: 'phone_register',
        target: PHONE_E164,
      });

      const verify = await http()
        .post('/auth/otp/verify')
        .send({ phone: PHONE, code: ctx.sender.last('phone_register') })
        .expect(200);
      const token = (verify.body as { phoneVerificationToken: string })
        .phoneVerificationToken;

      const reg = await http()
        .post('/auth/register')
        .send(registerBody(token, { email: 'Kasun@E2E.test ' }))
        .expect(201);
      const regBody = reg.body as {
        user: Record<string, unknown>;
        accessToken: string;
        refreshToken: string;
      };
      expect(regBody.user).toMatchObject({
        fullName: 'Kasun Perera',
        age: 34,
        email: EMAIL,
        emailVerified: false,
        phoneMasked: '+9477*****01',
        phoneVerified: true,
        nicMasked: '*******45V',
        language: 'en',
      });
      expect(Object.keys(regBody.user).sort()).toEqual([
        'age',
        'createdAt',
        'email',
        'emailVerified',
        'fullName',
        'id',
        'language',
        'nicMasked',
        'phoneMasked',
        'phoneVerified',
      ]);

      const me = await http()
        .get('/users/me')
        .set('Authorization', `Bearer ${regBody.accessToken}`)
        .expect(200);
      expect(me.body).toEqual(regBody.user);

      const stored = await pool.query<{
        phone_encrypted: Buffer;
        nic_encrypted: Buffer;
        password_hash: string;
        email_verified_at: Date | null;
      }>(
        'SELECT phone_encrypted, nic_encrypted, password_hash, email_verified_at FROM users WHERE email = $1',
        [EMAIL],
      );
      expect(stored.rows[0].phone_encrypted.toString('utf8')).not.toContain(
        '770000001',
      );
      expect(stored.rows[0].password_hash.startsWith('scrypt$32768$8$1$')).toBe(
        true,
      );
      expect(stored.rows[0].email_verified_at).toBeNull();

      await http()
        .post('/auth/logout')
        .set('Authorization', `Bearer ${regBody.accessToken}`)
        .expect(204);
      await http()
        .post('/auth/refresh')
        .send({ refreshToken: regBody.refreshToken })
        .expect(401);

      const byPhone = await http()
        .post('/auth/login')
        .send({ identifier: '+94770000001', password: PASSWORD })
        .expect(200);
      const byEmail = await http()
        .post('/auth/login')
        .send({ identifier: ' KASUN@e2e.test', password: PASSWORD })
        .expect(200);
      expect((byPhone.body as { user: unknown }).user).toEqual(regBody.user);
      expect((byEmail.body as { user: unknown }).user).toEqual(regBody.user);

      const r1 = (byEmail.body as { refreshToken: string }).refreshToken;
      const rotated = await http()
        .post('/auth/refresh')
        .send({ refreshToken: r1 })
        .expect(200);
      const r2 = (rotated.body as { refreshToken: string; accessToken: string })
        .refreshToken;
      expect(r2).not.toBe(r1);
      await http()
        .get('/users/me')
        .set(
          'Authorization',
          `Bearer ${(rotated.body as { accessToken: string }).accessToken}`,
        )
        .expect(200);

      // stale token fails and burns the session
      const stale = await http()
        .post('/auth/refresh')
        .send({ refreshToken: r1 })
        .expect(401);
      expect(stale.body).toMatchObject({
        statusCode: 401,
        code: 'INVALID_REFRESH_TOKEN',
      });
      await http().post('/auth/refresh').send({ refreshToken: r2 }).expect(401);
    });

    it('does not echo the code unless DEV_OTP_ECHO is on', async () => {
      const res = await http()
        .post('/auth/otp/request')
        .send({ phone: PHONE })
        .expect(200);
      expect(res.body).not.toHaveProperty('devCode');
      await ctx.app.close();
      ctx = await createApp({ DEV_OTP_ECHO: 'true' });
      const echoed = await http()
        .post('/auth/otp/request')
        .send({ phone: '0770000002' })
        .expect(200);
      expect((echoed.body as { devCode: string }).devCode).toBe(
        ctx.sender.last('phone_register'),
      );
    });

    it('PATCH /users/me updates language', async () => {
      const body = (await register()).body as { accessToken: string };
      const auth = { Authorization: `Bearer ${body.accessToken}` };
      const res = await http()
        .patch('/users/me')
        .set(auth)
        .send({ language: 'si' })
        .expect(200);
      expect((res.body as { language: string }).language).toBe('si');
      await http()
        .patch('/users/me')
        .set(auth)
        .send({ language: 'fr' })
        .expect(400);
    });
  });

  describe('login', () => {
    beforeEach(async () => {
      await register().then((r) => expect(r.status).toBe(201));
    });

    it('returns the same 401 for wrong password and unknown identifiers', async () => {
      const wrong = await http()
        .post('/auth/login')
        .send({ identifier: EMAIL, password: 'Wrong1234' })
        .expect(401);
      const unknownEmail = await http()
        .post('/auth/login')
        .send({ identifier: 'nobody@e2e.test', password: PASSWORD })
        .expect(401);
      const unknownPhone = await http()
        .post('/auth/login')
        .send({ identifier: '0779999999', password: PASSWORD })
        .expect(401);
      const junk = await http()
        .post('/auth/login')
        .send({ identifier: 'not a phone', password: PASSWORD })
        .expect(401);
      for (const r of [wrong, unknownEmail, unknownPhone, junk]) {
        expect(r.body).toEqual({
          statusCode: 401,
          code: 'INVALID_CREDENTIALS',
          message: 'Invalid credentials',
        });
      }
    });

    it('locks the account for 15 minutes after 5 consecutive failures', async () => {
      for (let i = 0; i < 5; i++) {
        await http()
          .post('/auth/login')
          .send({ identifier: EMAIL, password: 'Wrong1234' })
          .expect(401);
      }
      const locked = await http()
        .post('/auth/login')
        .send({ identifier: EMAIL, password: PASSWORD })
        .expect(429);
      expect((locked.body as { code: string }).code).toBe('ACCOUNT_LOCKED');
      ctx.clock.offsetMs += 15 * 60_000 + 1000;
      await http()
        .post('/auth/login')
        .send({ identifier: EMAIL, password: PASSWORD })
        .expect(200);
    });

    it('a successful login resets the failure counter', async () => {
      for (let i = 0; i < 4; i++) {
        await http()
          .post('/auth/login')
          .send({ identifier: EMAIL, password: 'Wrong1234' })
          .expect(401);
      }
      await http()
        .post('/auth/login')
        .send({ identifier: EMAIL, password: PASSWORD })
        .expect(200);
      await http()
        .post('/auth/login')
        .send({ identifier: EMAIL, password: 'Wrong1234' })
        .expect(401);
      await http()
        .post('/auth/login')
        .send({ identifier: EMAIL, password: PASSWORD })
        .expect(200);
    });
  });

  describe('registration conflicts and validation', () => {
    it('OTP request for a registered phone is 409', async () => {
      await register().then((r) => expect(r.status).toBe(201));
      const res = await http()
        .post('/auth/otp/request')
        .send({ phone: PHONE_E164 })
        .expect(409);
      expect(res.body).toMatchObject({ statusCode: 409, code: 'PHONE_TAKEN' });
    });

    it('duplicate phone, email and NIC are 409 with field codes', async () => {
      const t1 = await verifiedToken();
      await http().post('/auth/register').send(registerBody(t1)).expect(201);

      const phone = await http()
        .post('/auth/register')
        .send(registerBody(t1, { email: 'other@e2e.test', nic: '901234567V' }))
        .expect(409);
      expect(phone.body).toMatchObject({
        statusCode: 409,
        code: 'PHONE_TAKEN',
      });

      const t2 = await verifiedToken('0770000002');
      const email = await http()
        .post('/auth/register')
        .send(registerBody(t2, { phone: '0770000002', nic: '901234567V' }))
        .expect(409);
      expect(email.body).toMatchObject({
        statusCode: 409,
        code: 'EMAIL_TAKEN',
      });

      const nic = await http()
        .post('/auth/register')
        .send(
          registerBody(t2, {
            phone: '0770000002',
            email: 'other@e2e.test',
            nic: NIC.toLowerCase(),
          }),
        )
        .expect(409);
      expect(nic.body).toMatchObject({ statusCode: 409, code: 'NIC_TAKEN' });

      const ok = await http()
        .post('/auth/register')
        .send(
          registerBody(t2, {
            phone: '0770000002',
            email: 'other@e2e.test',
            nic: '901234567V',
          }),
        )
        .expect(201);
      expect(ok.body).toHaveProperty('accessToken');
    });

    it('rejects a token for a different phone', async () => {
      const token = await verifiedToken();
      const res = await http()
        .post('/auth/register')
        .send(registerBody(token, { phone: '0770000009' }))
        .expect(400);
      expect(res.body).toMatchObject({ code: 'INVALID_VERIFICATION_TOKEN' });
    });

    it('rejects garbage, access and refresh tokens as phone tokens', async () => {
      const reg = (await register()).body as {
        accessToken: string;
        refreshToken: string;
      };
      for (const t of ['garbage', reg.accessToken, reg.refreshToken]) {
        await http()
          .post('/auth/register')
          .send(
            registerBody(t, {
              phone: '0770000003',
              email: 'x@e2e.test',
              nic: '901234567V',
            }),
          )
          .expect(400);
      }
    });

    it('a phone verification token is not an access token', async () => {
      const token = await verifiedToken('0770000004');
      await http()
        .get('/users/me')
        .set('Authorization', `Bearer ${token}`)
        .expect(401);
    });

    it('validates the body strictly', async () => {
      const token = await verifiedToken();
      const bad: Record<string, unknown>[] = [
        { password: 'short1' },
        { password: 'onlyletters' },
        { password: '12345678' },
        { password: `a1${'x'.repeat(71)}` },
        { age: 17 },
        { age: 121 },
        { age: 30.5 },
        { age: '30' },
        { fullName: 'A' },
        { email: 'not-an-email' },
        { nic: '123' },
        { phone: '0112345678' },
        { extra: 'field' },
      ];
      for (const over of bad) {
        const res = await http()
          .post('/auth/register')
          .send(registerBody(token, over));
        expect([400]).toContain(res.status);
      }
      await http()
        .post('/auth/otp/request')
        .send({ phone: '12345' })
        .expect(400);
      await http()
        .post('/auth/otp/request')
        .send({ phone: PHONE, admin: true })
        .expect(400);
    });
  });

  describe('OTP', () => {
    it('wrong and expired codes give the same 400', async () => {
      await http().post('/auth/otp/request').send({ phone: PHONE }).expect(200);
      const code = ctx.sender.last('phone_register');
      const wrong = await http()
        .post('/auth/otp/verify')
        .send({ phone: PHONE, code: code === '000000' ? '111111' : '000000' })
        .expect(400);
      ctx.clock.offsetMs += 301_000;
      const expired = await http()
        .post('/auth/otp/verify')
        .send({ phone: PHONE, code })
        .expect(400);
      expect(expired.body).toEqual(wrong.body);
      expect(wrong.body).toEqual({
        statusCode: 400,
        code: 'INVALID_CODE',
        message: 'Invalid or expired code',
      });
    });

    it('locks after 5 wrong attempts, even for the right code', async () => {
      await http().post('/auth/otp/request').send({ phone: PHONE }).expect(200);
      const code = ctx.sender.last('phone_register');
      const bad = code === '000000' ? '111111' : '000000';
      for (let i = 0; i < 4; i++)
        await http()
          .post('/auth/otp/verify')
          .send({ phone: PHONE, code: bad })
          .expect(400);
      await http()
        .post('/auth/otp/verify')
        .send({ phone: PHONE, code: bad })
        .expect(429);
      const res = await http()
        .post('/auth/otp/verify')
        .send({ phone: PHONE, code })
        .expect(429);
      expect((res.body as { code: string }).code).toBe('OTP_LOCKED');
    });

    it('enforces the 30s resend cooldown and a new code replaces the old one', async () => {
      await http().post('/auth/otp/request').send({ phone: PHONE }).expect(200);
      const first = ctx.sender.last('phone_register');
      const res = await http()
        .post('/auth/otp/request')
        .send({ phone: '077 000 0001' })
        .expect(429);
      expect(res.body).toMatchObject({ code: 'OTP_COOLDOWN' });
      ctx.clock.offsetMs += 31_000;
      await http().post('/auth/otp/request').send({ phone: PHONE }).expect(200);
      const second = ctx.sender.last('phone_register');
      if (first !== second)
        await http()
          .post('/auth/otp/verify')
          .send({ phone: PHONE, code: first })
          .expect(400);
      await http()
        .post('/auth/otp/verify')
        .send({ phone: PHONE, code: second })
        .expect(200);
    });

    it('a code cannot be replayed', async () => {
      await http().post('/auth/otp/request').send({ phone: PHONE }).expect(200);
      const code = ctx.sender.last('phone_register');
      await http()
        .post('/auth/otp/verify')
        .send({ phone: PHONE, code })
        .expect(200);
      await http()
        .post('/auth/otp/verify')
        .send({ phone: PHONE, code })
        .expect(400);
    });

    it('stores only a hash of the code', async () => {
      await http().post('/auth/otp/request').send({ phone: PHONE }).expect(200);
      const code = ctx.sender.last('phone_register');
      const { rows } = await pool.query<{ code_hash: string }>(
        'SELECT code_hash FROM otp_challenges',
      );
      expect(rows).toHaveLength(1);
      expect(rows[0].code_hash).toMatch(/^[0-9a-f]{64}$/);
      expect(rows[0].code_hash).not.toContain(code);
    });
  });

  describe('authorization', () => {
    it('rejects unauthenticated and malformed credentials', async () => {
      for (const path of ['/users/me', '/users/me/email/otp']) {
        const method = path === '/users/me' ? 'get' : 'post';
        const res = await http()[method](path).expect(401);
        expect(res.body).toMatchObject({
          statusCode: 401,
          code: 'UNAUTHORIZED',
        });
      }
      await http()
        .get('/users/me')
        .set('Authorization', 'Bearer nonsense')
        .expect(401);
      await http()
        .get('/users/me')
        .set('Authorization', 'Basic abc')
        .expect(401);
      await http().post('/auth/logout').expect(401);
      await http().patch('/users/me').send({ language: 'en' }).expect(401);
    });

    it('a refresh token is not an access token', async () => {
      const reg = (await register()).body as { refreshToken: string };
      await http()
        .get('/users/me')
        .set('Authorization', `Bearer ${reg.refreshToken}`)
        .expect(401);
      await http()
        .post('/auth/refresh')
        .send({ refreshToken: 'garbage' })
        .expect(401);
    });

    it('health stays public', async () => {
      await http().get('/health').expect(200).expect({ status: 'ok' });
    });
  });

  describe('email verification', () => {
    it('sends an OTP to the email and marks it verified', async () => {
      const reg = (await register()).body as { accessToken: string };
      const auth = { Authorization: `Bearer ${reg.accessToken}` };

      const otp = await http()
        .post('/users/me/email/otp')
        .set(auth)
        .expect(200);
      expect(otp.body).toEqual({
        expiresInSeconds: 300,
        resendAfterSeconds: 30,
      });
      expect(ctx.sender.sent.at(-1)).toMatchObject({
        purpose: 'email_verify',
        target: EMAIL,
      });
      await http().post('/users/me/email/otp').set(auth).expect(429);

      const code = ctx.sender.last('email_verify');
      await http()
        .post('/users/me/email/verify')
        .set(auth)
        .send({ code: code === '000000' ? '111111' : '000000' })
        .expect(400);
      await http()
        .post('/users/me/email/verify')
        .set(auth)
        .send({ code: 'abc' })
        .expect(400);
      const ok = await http()
        .post('/users/me/email/verify')
        .set(auth)
        .send({ code })
        .expect(200);
      expect(ok.body).toEqual({ emailVerified: true });

      const me = await http().get('/users/me').set(auth).expect(200);
      expect((me.body as { emailVerified: boolean }).emailVerified).toBe(true);
      await http().post('/users/me/email/otp').set(auth).expect(409);
      await http()
        .post('/users/me/email/verify')
        .set(auth)
        .send({ code })
        .expect(409);
    });

    it('a phone-register code cannot verify an email', async () => {
      const reg = await register();
      const auth = {
        Authorization: `Bearer ${(reg.body as { accessToken: string }).accessToken}`,
      };
      const phoneCode = ctx.sender.last('phone_register');
      await http().post('/users/me/email/otp').set(auth).expect(200);
      const emailCode = ctx.sender.last('email_verify');
      if (phoneCode !== emailCode)
        await http()
          .post('/users/me/email/verify')
          .set(auth)
          .send({ code: phoneCode })
          .expect(400);
    });
  });

  describe('rate limiting', () => {
    it('throttles login at 5/min when enabled', async () => {
      await ctx.app.close();
      ctx = await createApp({ RATE_LIMIT_DISABLED: 'false' });
      const statuses: number[] = [];
      for (let i = 0; i < 7; i++) {
        const r = await http()
          .post('/auth/login')
          .send({ identifier: 'nobody@e2e.test', password: PASSWORD });
        statuses.push(r.status);
      }
      expect(statuses).toEqual([401, 401, 401, 401, 401, 429, 429]);
    });
  });

  describe('production safety', () => {
    it('refuses to boot with DEV_OTP_ECHO=true in production', () => {
      const res = spawnSync(
        process.execPath,
        ['-r', 'ts-node/register/transpile-only', 'src/main.ts'],
        {
          cwd: join(__dirname, '..'),
          env: {
            ...process.env,
            NODE_ENV: 'production',
            DEV_OTP_ECHO: 'true',
            RATE_LIMIT_DISABLED: 'false',
            CORS_ORIGINS: 'https://app.example.test',
            PORT: '0',
          },
          encoding: 'utf8',
          timeout: 60_000,
        },
      );
      expect(res.status).not.toBe(0);
      expect(`${res.stdout}${res.stderr}`).toMatch(
        /DEV_OTP_ECHO must not be true/,
      );
    }, 70_000);
  });
});
