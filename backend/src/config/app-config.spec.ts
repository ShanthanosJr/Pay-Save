import { randomBytes } from 'node:crypto';
import { loadConfig } from './app-config';

const base = {
  DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
  JWT_ACCESS_SECRET: 'a'.repeat(40),
  JWT_REFRESH_SECRET: 'b'.repeat(40),
  PII_ENCRYPTION_KEY: randomBytes(32).toString('base64'),
  PII_HMAC_KEY: randomBytes(32).toString('base64'),
};

describe('loadConfig', () => {
  it('applies dev defaults', () => {
    const cfg = loadConfig(base);
    expect(cfg.otpDelivery).toBe('console');
    expect(cfg.devOtpEcho).toBe(false);
    expect(cfg.corsOrigins).toBe('*');
  });

  it('refuses DEV_OTP_ECHO=true in production', () => {
    expect(() =>
      loadConfig({ ...base, NODE_ENV: 'production', DEV_OTP_ECHO: 'true' }),
    ).toThrow(/DEV_OTP_ECHO/);
    expect(
      loadConfig({ ...base, NODE_ENV: 'production', DEV_OTP_ECHO: 'false' })
        .devOtpEcho,
    ).toBe(false);
  });

  it('disables cors by default in production', () => {
    expect(loadConfig({ ...base, NODE_ENV: 'production' }).corsOrigins).toEqual(
      [],
    );
    expect(
      loadConfig({
        ...base,
        NODE_ENV: 'production',
        CORS_ORIGINS: 'https://a.com, https://b.com',
      }).corsOrigins,
    ).toEqual(['https://a.com', 'https://b.com']);
  });

  it('reports missing or malformed values', () => {
    expect(() => loadConfig({})).toThrow(/DATABASE_URL is required/);
    expect(() =>
      loadConfig({ ...base, PII_ENCRYPTION_KEY: 'c2hvcnQ=' }),
    ).toThrow(/PII_ENCRYPTION_KEY/);
    expect(() => loadConfig({ ...base, JWT_ACCESS_SECRET: 'short' })).toThrow(
      /JWT_ACCESS_SECRET/,
    );
    expect(() =>
      loadConfig({ ...base, JWT_REFRESH_SECRET: base.JWT_ACCESS_SECRET }),
    ).toThrow(/differ/);
    expect(() => loadConfig({ ...base, DEV_OTP_ECHO: 'yes' })).toThrow(
      /DEV_OTP_ECHO/,
    );
    expect(() => loadConfig({ ...base, OTP_DELIVERY: 'sms' })).toThrow(
      /OTP_DELIVERY/,
    );
  });
});
