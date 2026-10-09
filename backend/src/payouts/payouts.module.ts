import { Module } from '@nestjs/common';
import { TokensModule } from '../auth/tokens.module';
import { PayoutsController } from './payouts.controller';
import { PayoutsRepository } from './payouts.repository';
import { PayoutsService } from './payouts.service';

@Module({
  imports: [TokensModule],
  controllers: [PayoutsController],
  providers: [PayoutsRepository, PayoutsService],
  exports: [PayoutsService],
})
export class PayoutsModule {}
