import { Module } from '@nestjs/common';
import { TokensModule } from '../auth/tokens.module';
import { LedgerModule } from '../ledger/ledger.module';
import { CircleRoleGuard } from './circle-role.guard';
import { CirclesController } from './circles.controller';
import { CirclesRepository } from './circles.repository';
import { CirclesService } from './circles.service';

@Module({
  imports: [TokensModule, LedgerModule],
  controllers: [CirclesController],
  providers: [CirclesRepository, CirclesService, CircleRoleGuard],
  exports: [CirclesRepository, CirclesService, CircleRoleGuard],
})
export class CirclesModule {}
