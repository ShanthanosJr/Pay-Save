import { loadConfig } from '../config/app-config';
import { MessageOtpSender } from '../otp/message-otp-sender';
import { DeliveryError, EmailMessage, SmsMessage } from './messaging.types';
import {
  NotifyLkSmsTransport,
  TextLkSmsTransport,
  TwilioSmsTransport,
} from './sms.transports';

const cfg = loadConfig({
  DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
  JWT_ACCESS_SECRET: 'a'.repeat(40),
  JWT_REFRESH_SECRET: 'b'.repeat(40),
  PII_ENCRYPTION_KEY: Buffer.alloc(32, 1).toString('base64'),
  PII_HMAC_KEY: Buffer.alloc(32, 2).toString('base64'),
  SMS_PROVIDER: 'notifylk',
  NOTIFYLK_USER_ID: '111',
  NOTIFYLK_API_KEY: 'key',
  SMS_SENDER_ID: 'PayAndSave',
  TEXTLK_API_TOKEN: 'tok',
  TWILIO_ACCOUNT_SID: 'AC1',
  TWILIO_AUTH_TOKEN: 'secret',
  TWILIO_FROM: '+15550001111',
}).sms;

describe('SMS transports', () => {
  const fetchMock = jest.fn();
  const realFetch = global.fetch;
  beforeEach(() => {
    fetchMock.mockReset();
    global.fetch = fetchMock;
  });
  afterAll(() => {
    global.fetch = realFetch;
  });
  const reply = (status: number, body: unknown) =>
    fetchMock.mockResolvedValue({
      status,
      text: () => Promise.resolve(JSON.stringify(body)),
    });
  const call = () => fetchMock.mock.calls[0] as [string, RequestInit];

  it('notify.lk: posts the form without the plus and accepts success', async () => {
    reply(200, { status: 'success', data: 'Sent' });
    await new NotifyLkSmsTransport(cfg).send({
      to: '+94771234567',
      text: 'Pay&Save code: 123456',
    });
    const [url, init] = call();
    expect(url).toBe('https://app.notify.lk/api/v1/send');
    const form = new URLSearchParams(init.body as string);
    expect(Object.fromEntries(form)).toEqual({
      user_id: '111',
      api_key: 'key',
      sender_id: 'PayAndSave',
      to: '94771234567',
      message: 'Pay&Save code: 123456',
    });
  });

  it('notify.lk: marks Sinhala text as unicode and reports refusals', async () => {
    reply(200, { status: 'error' });
    const send = new NotifyLkSmsTransport(cfg).send({
      to: '+94771234567',
      text: 'කේතය 123456',
    });
    await expect(send).rejects.toBeInstanceOf(DeliveryError);
    await expect(send).rejects.not.toThrow(/123456/);
    expect(new URLSearchParams(call()[1].body as string).get('type')).toBe(
      'unicode',
    );
  });

  it('text.lk: bearer token and JSON body', async () => {
    reply(200, { status: 'success' });
    await new TextLkSmsTransport(cfg).send({ to: '+94771234567', text: 'hi' });
    const [url, init] = call();
    expect(url).toBe('https://app.text.lk/api/v3/sms/send');
    expect((init.headers as Record<string, string>).Authorization).toBe(
      'Bearer tok',
    );
    expect(JSON.parse(init.body as string)).toEqual({
      recipient: '94771234567',
      sender_id: 'PayAndSave',
      type: 'plain',
      message: 'hi',
    });
  });

  it('twilio: basic auth, E.164 recipient, non-2xx is a failure', async () => {
    reply(201, { sid: 'SM1' });
    await new TwilioSmsTransport(cfg).send({ to: '+94771234567', text: 'hi' });
    const [url, init] = call();
    expect(url).toContain('/Accounts/AC1/Messages.json');
    expect(new URLSearchParams(init.body as string).get('To')).toBe(
      '+94771234567',
    );
    reply(401, {});
    await expect(
      new TwilioSmsTransport(cfg).send({ to: '+94771234567', text: 'hi' }),
    ).rejects.toBeInstanceOf(DeliveryError);
  });

  it('a network error becomes a DeliveryError', async () => {
    fetchMock.mockRejectedValue(new TypeError('fetch failed'));
    await expect(
      new TextLkSmsTransport(cfg).send({ to: '+94771234567', text: 'hi' }),
    ).rejects.toBeInstanceOf(DeliveryError);
  });
});

describe('MessageOtpSender', () => {
  it('routes phones to SMS and addresses to email, in the user language', async () => {
    const sms: SmsMessage[] = [];
    const mail: EmailMessage[] = [];
    const sender = new MessageOtpSender(
      { send: (m) => Promise.resolve(void sms.push(m)) },
      { send: (m) => Promise.resolve(void mail.push(m)) },
    );
    await sender.send({
      purpose: 'phone_register',
      target: '+94771234567',
      code: '482913',
      language: 'ta',
    });
    await sender.send({
      purpose: 'password_reset',
      target: 'a@b.lk',
      code: '111222',
    });
    expect(sms).toHaveLength(1);
    expect(sms[0].text).toContain('482913');
    expect(sms[0].text).toContain('குறியீடு');
    expect(mail[0]).toMatchObject({
      to: 'a@b.lk',
      subject: 'Reset your Pay&Save password',
    });
    expect(mail[0].text).toContain('111222');
  });
});
