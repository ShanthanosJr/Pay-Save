export const OTP_SENDER = Symbol('OTP_SENDER');

export type OtpPurpose = 'phone_register' | 'email_verify' | 'password_reset';

export type OtpLanguage = 'en' | 'si' | 'ta';

export interface OtpMessage {
  purpose: OtpPurpose;
  /** E.164 phone number or email address; the channel follows from it. */
  target: string;
  code: string;
  language?: OtpLanguage;
}

export interface OtpSender {
  send(message: OtpMessage): Promise<void>;
}
