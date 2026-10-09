import { Module } from '@nestjs/common';
import { TokensModule } from '../auth/tokens.module';
import { LedgerModule } from '../ledger/ledger.module';
import { PayoutsModule } from '../payouts/payouts.module';
import { CircleInvitationsRepository } from './circle-invitations.repository';
import { CircleInvitationsService } from './circle-invitations.service';
import { CircleRoleGuard } from './circle-role.guard';
import {
  CircleInvitationsController,
  CirclesController,
} from './circles.controller';
import { CirclesRepository } from './circles.repository';
import { CirclesService } from './circles.service';

@Module({
  imports: [TokensModule, LedgerModule, PayoutsModule],
  controllers: [CirclesController, CircleInvitationsController],
  providers: [
    CirclesRepository,
    CirclesService,
    CircleRoleGuard,
    CircleInvitationsRepository,
    CircleInvitationsService,
  ],
  exports: [CirclesRepository, CirclesService, CircleRoleGuard],
})
export class CirclesModule {}
