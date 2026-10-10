import { Logger } from '@nestjs/common';
import type { AppConfig } from '../config/app-config';
import { DeliveryError, SmsMessage, SmsTransport } from './messaging.types';

const TIMEOUT_MS = 10_000;

/** Sinhala and Tamil need a UCS-2 message. */
const isUnicode = (text: string) => /[^\u0020-\u007e\n\r]/.test(text);

const mask = (v: string) =>
  `${'*'.repeat(Math.max(0, v.length - 3))}${v.slice(-3)}`;

/** Sri Lankan gateways take 9477XXXXXXX, without the plus. */
const withoutPlus = (e164: string) => e164.replace(/^\+/, '');

async function post(
  url: string,
  init: RequestInit,
): Promise<{ status: number; body: string }> {
  try {
    const res = await fetch(url, {
      ...init,
      method: 'POST',
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    return { status: res.status, body: await res.text() };
  } catch (err) {
    throw new DeliveryError('sms', (err as Error).name);
  }
}

const parse = (body: string): Record<string, unknown> => {
  try {
    return JSON.parse(body) as Record<string, unknown>;
  } catch {
    return {};
  }
};

/** Development only: prints the message instead of sending it. */
export class ConsoleSmsTransport implements SmsTransport {
  private readonly logger = new Logger('Sms');

  send({ to, text }: SmsMessage): Promise<void> {
    this.logger.log(`[SMS] ${mask(to)} ${text}`);
    return Promise.resolve();
  }
}

/** https://developer.notify.lk/api-endpoints/ */
export class NotifyLkSmsTransport implements SmsTransport {
  constructor(private readonly cfg: AppConfig['sms']) {}

  async send({ to, text }: SmsMessage): Promise<void> {
    const form = new URLSearchParams({
      user_id: this.cfg.notifyLkUserId,
      api_key: this.cfg.notifyLkApiKey,
      sender_id: this.cfg.senderId,
      to: withoutPlus(to),
      message: text,
      ...(isUnicode(text) ? { type: 'unicode' } : {}),
    });
    const res = await post('https://app.notify.lk/api/v1/send', {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: form.toString(),
    });
    if (res.status !== 200 || parse(res.body).status !== 'success')
      throw new DeliveryError('sms', `notifylk ${res.status}`);
  }
}

/** https://text.lk/docs/send-sms/ */
export class TextLkSmsTransport implements SmsTransport {
  constructor(private readonly cfg: AppConfig['sms']) {}

  async send({ to, text }: SmsMessage): Promise<void> {
    const res = await post('https://app.text.lk/api/v3/sms/send', {
      headers: {
        Authorization: `Bearer ${this.cfg.textLkApiToken}`,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({
        recipient: withoutPlus(to),
        sender_id: this.cfg.senderId,
        type: isUnicode(text) ? 'unicode' : 'plain',
        message: text,
      }),
    });
    if (res.status >= 300 || parse(res.body).status !== 'success')
      throw new DeliveryError('sms', `textlk ${res.status}`);
  }
}

/** https://www.twilio.com/docs/messaging/api/message-resource */
export class TwilioSmsTransport implements SmsTransport {
  constructor(private readonly cfg: AppConfig['sms']) {}

  async send({ to, text }: SmsMessage): Promise<void> {
    const sid = this.cfg.twilioAccountSid;
    const auth = Buffer.from(`${sid}:${this.cfg.twilioAuthToken}`).toString(
      'base64',
    );
    const res = await post(
      `https://api.twilio.com/2010-04-01/Accounts/${encodeURIComponent(sid)}/Messages.json`,
      {
        headers: {
          Authorization: `Basic ${auth}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({
          To: to,
          From: this.cfg.twilioFrom,
          Body: text,
        }).toString(),
      },
    );
    if (res.status >= 300)
      throw new DeliveryError('sms', `twilio ${res.status}`);
  }
}

export function createSmsTransport(cfg: AppConfig['sms']): SmsTransport {
  if (cfg.provider !== 'console' && /demo/i.test(cfg.senderId))
    new Logger('Sms').warn(
      `SMS_SENDER_ID "${cfg.senderId}" is a gateway demo sender: it replaces every message ` +
        'with a test notice, so codes will NOT arrive. Use your own approved sender id.',
    );
  switch (cfg.provider) {
    case 'notifylk':
      return new NotifyLkSmsTransport(cfg);
    case 'textlk':
      return new TextLkSmsTransport(cfg);
    case 'twilio':
      return new TwilioSmsTransport(cfg);
    default:
      return new ConsoleSmsTransport();
  }
}
