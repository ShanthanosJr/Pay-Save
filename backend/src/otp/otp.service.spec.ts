import { randomBytes } from 'node:crypto';
import type { Clock } from '../common/clock/clock';
import { AppException } from '../common/errors/app.exception';
import { CryptoService } from '../common/crypto/crypto.service';
import { NewOtpChallenge, OtpChallenge, OtpRepository } from './otp.repository';
import { OtpService } from './otp.service';
import type { OtpSender } from './otp-sender';

class FakeClock implements Clock {
  constructor(public current = new Date('2026-01-01T00:00:00Z')) {}
  now(): Date {
    return new Date(this.current);
  }
  advance(seconds: number): void {
    this.current = new Date(this.current.getTime() + seconds * 1000);
  }
}

class FakeRepo {
  rows: OtpChallenge[] = [];
  private seq = 0;
  findLatest(purpose: string, targetHash: string) {
    const m = this.rows.filter(
      (r) => r.purpose === purpose && r.targetHash === targetHash,
    );
    return Promise.resolve(
      m.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())[0] ??
        null,
    );
  }
  invalidateActive(purpose: string, targetHash: string, at: Date) {
    for (const r of this.rows) {
      if (r.purpose === purpose && r.targetHash === targetHash && !r.consumedAt)
        r.consumedAt = at;
    }
    return Promise.resolve();
  }
  insert(c: NewOtpChallenge) {
    const row: OtpChallenge = {
      ...c,
      id: String(++this.seq),
      attempts: 0,
      consumedAt: null,
    };
    this.rows.push(row);
    return Promise.resolve(row);
  }
  incrementAttempts(id: string) {
    const r = this.rows.find((x) => x.id === id)!;
    return Promise.resolve(++r.attempts);
  }
  consume(id: string, at: Date) {
    const r = this.rows.find((x) => x.id === id)!;
    if (r.consumedAt) return Promise.resolve(false);
    r.consumedAt = at;
    return Promise.resolve(true);
  }
}

describe('OtpService', () => {
  let clock: FakeClock;
  let repo: FakeRepo;
  let sent: { purpose: string; target: string; code: string }[];
  let svc: OtpService;
  const target = '+94771234567';

  beforeEach(() => {
    clock = new FakeClock();
    repo = new FakeRepo();
    sent = [];
    const sender: OtpSender = {
      send: (m) => {
        sent.push(m);
        return Promise.resolve();
      },
    };
    const crypto = new CryptoService({
      piiEncryptionKey: randomBytes(32),
      piiHmacKey: randomBytes(32),
    });
    svc = new OtpService(
      repo as unknown as OtpRepository,
      sender,
      crypto,
      clock,
    );
  });

  const wrong = (code: string) => (code === '000000' ? '111111' : '000000');
  const status = async (p: Promise<unknown>): Promise<number> => {
    try {
      await p;
      return 200;
    } catch (e) {
      return (e as AppException).getStatus();
    }
  };

  it('issues a 6-digit code, stores only its hash, and sends it', async () => {
    const r = await svc.issue('phone_register', target);
    expect(r.code).toMatch(/^\d{6}$/);
    expect(r).toMatchObject({ expiresInSeconds: 300, resendAfterSeconds: 30 });
    expect(sent).toEqual([{ purpose: 'phone_register', target, code: r.code }]);
    expect(JSON.stringify(repo.rows)).not.toContain(r.code);
  });

  it('accepts the right code once', async () => {
    const { code } = await svc.issue('phone_register', target);
    await expect(
      svc.verify('phone_register', target, code),
    ).resolves.toBeUndefined();
    expect(await status(svc.verify('phone_register', target, code))).toBe(400);
  });

  it('expires after 5 minutes with the same error as a wrong code', async () => {
    const { code } = await svc.issue('phone_register', target);
    clock.advance(300);
    expect(await status(svc.verify('phone_register', target, code))).toBe(400);
    const err = await svc
      .verify('phone_register', target, wrong(code))
      .catch((e: AppException) => e);
    expect((err as AppException).code).toBe('INVALID_CODE');
  });

  it('is still valid just before expiry', async () => {
    const { code } = await svc.issue('phone_register', target);
    clock.advance(299);
    await expect(
      svc.verify('phone_register', target, code),
    ).resolves.toBeUndefined();
  });

  it('kills the challenge after 5 wrong attempts', async () => {
    const { code } = await svc.issue('phone_register', target);
    const statuses: number[] = [];
    for (let i = 0; i < 5; i++)
      statuses.push(
        await status(svc.verify('phone_register', target, wrong(code))),
      );
    expect(statuses).toEqual([400, 400, 400, 400, 429]);
    expect(await status(svc.verify('phone_register', target, code))).toBe(429);
  });

  it('enforces a 30s resend cooldown per target and purpose', async () => {
    await svc.issue('phone_register', target);
    expect(await status(svc.issue('phone_register', target))).toBe(429);
    await expect(svc.issue('email_verify', target)).resolves.toBeDefined();
    await expect(
      svc.issue('phone_register', '+94770000000'),
    ).resolves.toBeDefined();
    clock.advance(29);
    expect(await status(svc.issue('phone_register', target))).toBe(429);
    clock.advance(1);
    await expect(svc.issue('phone_register', target)).resolves.toBeDefined();
  });

  it('a new request invalidates the previous code', async () => {
    const first = await svc.issue('phone_register', target);
    clock.advance(31);
    const second = await svc.issue('phone_register', target);
    if (first.code !== second.code) {
      expect(
        await status(svc.verify('phone_register', target, first.code)),
      ).toBe(400);
    }
    expect(repo.rows.filter((r) => !r.consumedAt)).toHaveLength(1);
    await expect(
      svc.verify('phone_register', target, second.code),
    ).resolves.toBeUndefined();
  });

  it('rejects verification when nothing was requested', async () => {
    expect(await status(svc.verify('phone_register', target, '123456'))).toBe(
      400,
    );
  });
});
