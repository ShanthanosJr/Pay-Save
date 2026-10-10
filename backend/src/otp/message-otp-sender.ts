import { Inject, Injectable } from '@nestjs/common';
import { EMAIL_TRANSPORT, SMS_TRANSPORT } from '../messaging/messaging.types';
import type {
  EmailTransport,
  SmsTransport,
} from '../messaging/messaging.types';
import type { OtpMessage, OtpSender } from './otp-sender';
import { otpEmail, otpSms } from './otp-templates';

/** Delivers codes by SMS to phone numbers and by email to addresses. */
@Injectable()
export class MessageOtpSender implements OtpSender {
  constructor(
    @Inject(SMS_TRANSPORT) private readonly sms: SmsTransport,
    @Inject(EMAIL_TRANSPORT) private readonly email: EmailTransport,
  ) {}

  send({ purpose, target, code, language }: OtpMessage): Promise<void> {
    if (target.includes('@'))
      return this.email.send({
        to: target,
        ...otpEmail(purpose, code, language),
      });
    return this.sms.send({ to: target, text: otpSms(code, language) });
  }
}
