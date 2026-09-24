process.env.NODE_ENV = 'test';
process.env.DEV_OTP_ECHO = 'false';
process.env.RATE_LIMIT_DISABLED = 'true';
process.env.OTP_DELIVERY = 'console';
process.env.DATABASE_URL ??=
  'postgresql://payandsave:payandsave@localhost:5432/payandsave';
process.env.JWT_ACCESS_SECRET ??= 'e2e-access-secret-e2e-access-secret-0000';
process.env.JWT_REFRESH_SECRET ??= 'e2e-refresh-secret-e2e-refresh-secret-111';
process.env.PII_ENCRYPTION_KEY ??= Buffer.alloc(32, 7).toString('base64');
process.env.PII_HMAC_KEY ??= Buffer.alloc(32, 9).toString('base64');
