export const APP_CONFIG = Symbol('APP_CONFIG');

export interface AppConfig {
  nodeEnv: string;
  databaseUrl: string;
  jwtAccessSecret: string;
  jwtRefreshSecret: string;
  piiEncryptionKey: Buffer;
  piiHmacKey: Buffer;
  otpDelivery: 'console';
  devOtpEcho: boolean;
  corsOrigins: string[] | '*';
  rateLimitDisabled: boolean;
}

type Env = Record<string, string | undefined>;

export function loadConfig(env: Env): AppConfig {
  const errors: string[] = [];
  const nodeEnv = env.NODE_ENV || 'development';
  const isProd = nodeEnv === 'production';

  const required = (name: string): string => {
    const v = env[name];
    if (!v) errors.push(`${name} is required`);
    return v ?? '';
  };
  const secret = (name: string): string => {
    const v = required(name);
    if (v && v.length < 32)
      errors.push(`${name} must be at least 32 characters`);
    return v;
  };
  const bool = (name: string): boolean => {
    const v = env[name];
    if (v === undefined || v === '') return false;
    if (v !== 'true' && v !== 'false')
      errors.push(`${name} must be true or false`);
    return v === 'true';
  };
  const key = (name: string): Buffer => {
    const v = required(name);
    const buf = Buffer.from(v, 'base64');
    if (v && buf.length !== 32)
      errors.push(`${name} must be 32 bytes, base64-encoded`);
    return buf;
  };

  const databaseUrl = required('DATABASE_URL');
  const jwtAccessSecret = secret('JWT_ACCESS_SECRET');
  const jwtRefreshSecret = secret('JWT_REFRESH_SECRET');
  if (jwtAccessSecret && jwtAccessSecret === jwtRefreshSecret) {
    errors.push('JWT_ACCESS_SECRET and JWT_REFRESH_SECRET must differ');
  }
  const piiEncryptionKey = key('PII_ENCRYPTION_KEY');
  const piiHmacKey = key('PII_HMAC_KEY');

  const otpDelivery = env.OTP_DELIVERY || 'console';
  if (otpDelivery !== 'console') errors.push('OTP_DELIVERY must be console');

  const devOtpEcho = bool('DEV_OTP_ECHO');
  const rateLimitDisabled = bool('RATE_LIMIT_DISABLED');
  if (isProd && devOtpEcho)
    errors.push('DEV_OTP_ECHO must not be true when NODE_ENV=production');
  if (isProd && rateLimitDisabled)
    errors.push(
      'RATE_LIMIT_DISABLED must not be true when NODE_ENV=production',
    );

  let corsOrigins: string[] | '*';
  if (env.CORS_ORIGINS) {
    corsOrigins =
      env.CORS_ORIGINS === '*'
        ? '*'
        : env.CORS_ORIGINS.split(',')
            .map((s) => s.trim())
            .filter(Boolean);
    if (isProd && corsOrigins === '*')
      errors.push('CORS_ORIGINS must not be * in production');
  } else {
    corsOrigins = isProd ? [] : '*';
  }

  if (errors.length > 0)
    throw new Error(`Invalid configuration: ${errors.join('; ')}`);

  return {
    nodeEnv,
    databaseUrl,
    jwtAccessSecret,
    jwtRefreshSecret,
    piiEncryptionKey,
    piiHmacKey,
    otpDelivery: 'console',
    devOtpEcho,
    corsOrigins,
    rateLimitDisabled,
  };
}
