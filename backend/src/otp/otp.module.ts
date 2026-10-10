import { Module } from '@nestjs/common';
import { MessageOtpSender } from './message-otp-sender';
import { OtpRepository } from './otp.repository';
import { OtpService } from './otp.service';
import { OTP_SENDER } from './otp-sender';

@Module({
  providers: [
    OtpRepository,
    OtpService,
    { provide: OTP_SENDER, useClass: MessageOtpSender },
  ],
  exports: [OtpService],
})
export class OtpModule {}
