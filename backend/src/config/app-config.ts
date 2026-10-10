export const APP_CONFIG = Symbol('APP_CONFIG');

export interface AppConfig {
  nodeEnv: string;
  databaseUrl: string;
  jwtAccessSecret: string;
  jwtRefreshSecret: string;
  piiEncryptionKey: Buffer;
  piiHmacKey: Buffer;
  sms: SmsConfig;
  email: EmailConfig;
  /** Where the API is reachable from outside, for links in statements. */
  publicBaseUrl: string;
  devOtpEcho: boolean;
  corsOrigins: string[] | '*';
  rateLimitDisabled: boolean;
}

export type SmsProvider = 'console' | 'notifylk' | 'textlk' | 'twilio';
export type EmailProvider = 'console' | 'smtp';

export interface SmsConfig {
  provider: SmsProvider;
  /** Approved alphanumeric sender (notifylk, textlk). */
  senderId: string;
  notifyLkUserId: string;
  notifyLkApiKey: string;
  textLkApiToken: string;
  twilioAccountSid: string;
  twilioAuthToken: string;
  twilioFrom: string;
}

export interface EmailConfig {
  provider: EmailProvider;
  from: string;
  smtpHost: string;
  smtpPort: number;
  smtpSecure: boolean;
  smtpUser: string;
  smtpPass: string;
}

const SMS_REQUIRED: Record<SmsProvider, string[]> = {
  console: [],
  notifylk: ['NOTIFYLK_USER_ID', 'NOTIFYLK_API_KEY', 'SMS_SENDER_ID'],
  textlk: ['TEXTLK_API_TOKEN', 'SMS_SENDER_ID'],
  twilio: ['TWILIO_ACCOUNT_SID', 'TWILIO_AUTH_TOKEN', 'TWILIO_FROM'],
};

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

  // OTP_DELIVERY=console is the pre-gateway name; SMS_PROVIDER wins.
  const smsProvider = (env.SMS_PROVIDER ||
    env.OTP_DELIVERY ||
    'console') as SmsProvider;
  if (!(smsProvider in SMS_REQUIRED))
    errors.push('SMS_PROVIDER must be console, notifylk, textlk or twilio');
  else SMS_REQUIRED[smsProvider].forEach(required);
  const emailProvider = (env.EMAIL_PROVIDER || 'console') as EmailProvider;
  if (emailProvider !== 'console' && emailProvider !== 'smtp')
    errors.push('EMAIL_PROVIDER must be console or smtp');
  if (emailProvider === 'smtp') ['SMTP_HOST', 'EMAIL_FROM'].forEach(required);
  const smtpPort = Number(env.SMTP_PORT || 587);
  if (!Number.isInteger(smtpPort) || smtpPort < 1 || smtpPort > 65535)
    errors.push('SMTP_PORT must be a port number');
  // Gateways' shared demo senders deliver a canned text instead of ours.
  if (isProd && /demo/i.test(env.SMS_SENDER_ID ?? ''))
    errors.push('SMS_SENDER_ID must be your own approved sender id');
  // Codes that only reach a server log are not verification.
  if (isProd && smsProvider === 'console')
    errors.push('SMS_PROVIDER must be a real gateway when NODE_ENV=production');
  if (isProd && emailProvider === 'console')
    errors.push('EMAIL_PROVIDER must be smtp when NODE_ENV=production');
  const publicBaseUrl = (
    env.PUBLIC_BASE_URL || `http://localhost:${env.PORT || 3000}`
  ).replace(/\/+$/, '');
  if (isProd && !publicBaseUrl.startsWith('https://'))
    errors.push('PUBLIC_BASE_URL must be https in production');

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
    sms: {
      provider: smsProvider,
      senderId: env.SMS_SENDER_ID ?? '',
      notifyLkUserId: env.NOTIFYLK_USER_ID ?? '',
      notifyLkApiKey: env.NOTIFYLK_API_KEY ?? '',
      textLkApiToken: env.TEXTLK_API_TOKEN ?? '',
      twilioAccountSid: env.TWILIO_ACCOUNT_SID ?? '',
      twilioAuthToken: env.TWILIO_AUTH_TOKEN ?? '',
      twilioFrom: env.TWILIO_FROM ?? '',
    },
    email: {
      provider: emailProvider,
      from: env.EMAIL_FROM ?? 'Pay&Save <no-reply@localhost>',
      smtpHost: env.SMTP_HOST ?? '',
      smtpPort,
      smtpSecure: env.SMTP_SECURE
        ? env.SMTP_SECURE === 'true'
        : smtpPort === 465,
      smtpUser: env.SMTP_USER ?? '',
      smtpPass: env.SMTP_PASS ?? '',
    },
    publicBaseUrl,
    devOtpEcho,
    corsOrigins,
    rateLimitDisabled,
  };
}
