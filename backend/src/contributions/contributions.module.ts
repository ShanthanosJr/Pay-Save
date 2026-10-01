import { Module } from '@nestjs/common';
import { TokensModule } from '../auth/tokens.module';
import { CirclesModule } from '../circles/circles.module';
import { LedgerModule } from '../ledger/ledger.module';
import { ContributionsController } from './contributions.controller';
import { ContributionsService } from './contributions.service';

@Module({
  imports: [TokensModule, LedgerModule, CirclesModule],
  controllers: [ContributionsController],
  providers: [ContributionsService],
})
export class ContributionsModule {}
