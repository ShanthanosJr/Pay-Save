import { Module } from '@nestjs/common';
import { TokensModule } from '../auth/tokens.module';
import { CirclesModule } from '../circles/circles.module';
import { RemindersController } from './reminders.controller';
import { RemindersService } from './reminders.service';

@Module({
  imports: [TokensModule, CirclesModule],
  controllers: [RemindersController],
  providers: [RemindersService],
  exports: [RemindersService],
})
export class RemindersModule {}
