import { Global, Module } from '@nestjs/common';
import { APP_CONFIG } from '../config/app-config';
import type { AppConfig } from '../config/app-config';
import { createEmailTransport } from './email.transports';
import { EMAIL_TRANSPORT, SMS_TRANSPORT } from './messaging.types';
import { createSmsTransport } from './sms.transports';

/** Outbound SMS and email. Tests override the two transport tokens. */
@Global()
@Module({
  providers: [
    {
      provide: SMS_TRANSPORT,
      inject: [APP_CONFIG],
      useFactory: (cfg: AppConfig) => createSmsTransport(cfg.sms),
    },
    {
      provide: EMAIL_TRANSPORT,
      inject: [APP_CONFIG],
      useFactory: (cfg: AppConfig) => createEmailTransport(cfg.email),
    },
  ],
  exports: [SMS_TRANSPORT, EMAIL_TRANSPORT],
})
export class MessagingModule {}
