export const SMS_TRANSPORT = Symbol('SMS_TRANSPORT');
export const EMAIL_TRANSPORT = Symbol('EMAIL_TRANSPORT');

export interface SmsMessage {
  /** E.164, e.g. +94771234567 */
  to: string;
  text: string;
}

export interface EmailMessage {
  to: string;
  subject: string;
  text: string;
}

export interface SmsTransport {
  send(message: SmsMessage): Promise<void>;
}

export interface EmailTransport {
  send(message: EmailMessage): Promise<void>;
}

/** Raised when a gateway refuses or cannot be reached; never carries the message body. */
export class DeliveryError extends Error {
  constructor(
    readonly channel: 'sms' | 'email',
    detail: string,
  ) {
    super(`${channel} delivery failed: ${detail}`);
  }
}
