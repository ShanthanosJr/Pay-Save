import { Injectable, Logger } from '@nestjs/common';
import { OtpPurpose } from './otp-sender';
import type { OtpSender } from './otp-sender';

@Injectable()
export class ConsoleOtpSender implements OtpSender {
  private readonly logger = new Logger('OtpSender');

  send({
    purpose,
    target,
    code,
  }: {
    purpose: OtpPurpose;
    target: string;
    code: string;
  }): Promise<void> {
    const masked = `${'*'.repeat(Math.max(0, target.length - 3))}${target.slice(-3)}`;
    this.logger.log(`[OTP] ${purpose} ${masked} ${code}`);
    return Promise.resolve();
  }
}
