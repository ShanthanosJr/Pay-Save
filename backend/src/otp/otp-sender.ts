export const OTP_SENDER = Symbol('OTP_SENDER');

export type OtpPurpose = 'phone_register' | 'email_verify';

export interface OtpSender {
  send(message: {
    purpose: OtpPurpose;
    target: string;
    code: string;
  }): Promise<void>;
}
