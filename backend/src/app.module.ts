import { Module, ValidationPipe } from '@nestjs/common';
import { APP_GUARD, APP_PIPE } from '@nestjs/core';
import { ThrottlerModule } from '@nestjs/throttler';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { AuthModule } from './auth/auth.module';
import { TokensModule } from './auth/tokens.module';
import { UserThrottlerGuard } from './common/user-throttler.guard';
import { CirclesModule } from './circles/circles.module';
import { CommonModule } from './common/common.module';
import { ContributionsModule } from './contributions/contributions.module';
import { APP_CONFIG } from './config/app-config';
import type { AppConfig } from './config/app-config';
import { AppConfigModule } from './config/app-config.module';
import { DatabaseModule } from './database/database.module';
import { HealthModule } from './health/health.module';
import { ScheduleModule } from '@nestjs/schedule';
import { NotificationsModule } from './notifications/notifications.module';
import { CommunityModule } from './community/community.module';
import { StatementsModule } from './statements/statements.module';
import { RemindersModule } from './reminders/reminders.module';
import { MessagingModule } from './messaging/messaging.module';
import { LedgerModule } from './ledger/ledger.module';
import { PayoutsModule } from './payouts/payouts.module';
import { SocialModule } from './social/social.module';
import { UsersModule } from './users/users.module';

@Module({
  imports: [
    AppConfigModule,
    CommonModule,
    DatabaseModule,
    MessagingModule,
    ScheduleModule.forRoot(),
    NotificationsModule,
    ThrottlerModule.forRootAsync({
      inject: [APP_CONFIG],
      useFactory: (cfg: AppConfig) => ({
        throttlers: [{ ttl: 60_000, limit: 120 }],
        skipIf: () => cfg.rateLimitDisabled,
      }),
    }),
    TokensModule,
    HealthModule,
    AuthModule,
    UsersModule,
    LedgerModule,
    CirclesModule,
    ContributionsModule,
    SocialModule,
    PayoutsModule,
    RemindersModule,
    StatementsModule,
    CommunityModule,
  ],
  controllers: [AppController],
  providers: [
    AppService,
    { provide: APP_GUARD, useClass: UserThrottlerGuard },
    {
      provide: APP_PIPE,
      useValue: new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
      }),
    },
  ],
})
export class AppModule {}
