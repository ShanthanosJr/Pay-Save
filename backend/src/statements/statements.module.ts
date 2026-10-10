import { Module } from '@nestjs/common';
import { TokensModule } from '../auth/tokens.module';
import { CirclesModule } from '../circles/circles.module';
import {
  StatementVerifyController,
  StatementsController,
} from './statements.controller';
import { StatementsService } from './statements.service';

@Module({
  imports: [TokensModule, CirclesModule],
  controllers: [StatementsController, StatementVerifyController],
  providers: [StatementsService],
})
export class StatementsModule {}
