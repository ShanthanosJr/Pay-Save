import { randomBytes } from 'node:crypto';
import { loadConfig } from './app-config';

const live = {
  SMS_PROVIDER: 'textlk',
  TEXTLK_API_TOKEN: 'token',
  SMS_SENDER_ID: 'PayAndSave',
  EMAIL_PROVIDER: 'smtp',
  SMTP_HOST: 'smtp.example.com',
  EMAIL_FROM: 'Pay&Save <no-reply@example.com>',
  PUBLIC_BASE_URL: 'https://api.example.com',
};

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
    expect(cfg.sms.provider).toBe('console');
    expect(cfg.email.provider).toBe('console');
    expect(cfg.devOtpEcho).toBe(false);
    expect(cfg.corsOrigins).toBe('*');
  });

  it('refuses DEV_OTP_ECHO=true in production', () => {
    expect(() =>
      loadConfig({
        ...base,
        ...live,
        NODE_ENV: 'production',
        DEV_OTP_ECHO: 'true',
      }),
    ).toThrow(/DEV_OTP_ECHO/);
    expect(
      loadConfig({
        ...base,
        ...live,
        NODE_ENV: 'production',
        DEV_OTP_ECHO: 'false',
      }).devOtpEcho,
    ).toBe(false);
  });

  it('disables cors by default in production', () => {
    expect(
      loadConfig({ ...base, ...live, NODE_ENV: 'production' }).corsOrigins,
    ).toEqual([]);
    expect(
      loadConfig({
        ...base,
        ...live,
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
    expect(() => loadConfig({ ...base, SMS_PROVIDER: 'pigeon' })).toThrow(
      /SMS_PROVIDER/,
    );
  });

  it('requires the chosen gateway to be fully configured', () => {
    expect(() => loadConfig({ ...base, SMS_PROVIDER: 'notifylk' })).toThrow(
      /NOTIFYLK_USER_ID is required.*NOTIFYLK_API_KEY is required.*SMS_SENDER_ID is required/,
    );
    expect(() => loadConfig({ ...base, EMAIL_PROVIDER: 'smtp' })).toThrow(
      /SMTP_HOST is required.*EMAIL_FROM is required/,
    );
    const cfg = loadConfig({ ...base, ...live, SMTP_PORT: '465' });
    expect(cfg.sms.provider).toBe('textlk');
    expect(cfg.email.smtpSecure).toBe(true);
  });

  it('refuses console delivery and plain http links in production', () => {
    expect(() => loadConfig({ ...base, NODE_ENV: 'production' })).toThrow(
      /SMS_PROVIDER must be a real gateway.*EMAIL_PROVIDER must be smtp.*PUBLIC_BASE_URL must be https/,
    );
  });
});
