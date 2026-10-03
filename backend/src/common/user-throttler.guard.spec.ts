import { UserThrottlerGuard } from './user-throttler.guard';
import type { TokenService } from '../auth/token.service';

describe('UserThrottlerGuard tracker', () => {
  const tokens = {
    verifyAccess: jest.fn((t: string) =>
      Promise.resolve(t === 'good' ? 'user-1' : null),
    ),
  } as unknown as TokenService;
  const guard = new UserThrottlerGuard(
    { throttlers: [] },
    {} as never,
    {} as never,
    tokens,
  );
  const track = (req: object) =>
    (guard as unknown as { getTracker(r: object): Promise<string> }).getTracker(
      req,
    );

  it('buckets a verified user by user id, not by shared carrier IP', async () => {
    await expect(
      track({
        ip: '10.0.0.1',
        path: '/circles',
        headers: { authorization: 'Bearer good' },
      }),
    ).resolves.toBe('user:user-1');
  });

  it('falls back to IP for missing or invalid tokens', async () => {
    await expect(
      track({ ip: '10.0.0.1', path: '/circles', headers: {} }),
    ).resolves.toBe('ip:10.0.0.1');
    await expect(
      track({
        ip: '10.0.0.1',
        path: '/circles',
        headers: { authorization: 'Bearer bad' },
      }),
    ).resolves.toBe('ip:10.0.0.1');
  });

  it('keeps auth routes per IP even with a valid token', async () => {
    await expect(
      track({
        ip: '10.0.0.2',
        path: '/auth/login',
        headers: { authorization: 'Bearer good' },
      }),
    ).resolves.toBe('ip:10.0.0.2');
  });
});
