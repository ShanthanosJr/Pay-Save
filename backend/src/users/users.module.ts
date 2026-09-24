import { Module } from '@nestjs/common';
import { TokensModule } from '../auth/tokens.module';
import { OtpModule } from '../otp/otp.module';
import { UsersController } from './users.controller';
import { UsersRepository } from './users.repository';
import { UsersService } from './users.service';

@Module({
  imports: [TokensModule, OtpModule],
  controllers: [UsersController],
  providers: [UsersRepository, UsersService],
  exports: [UsersRepository, UsersService],
})
export class UsersModule {}
