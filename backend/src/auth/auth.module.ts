import { Module } from '@nestjs/common';
import { OtpModule } from '../otp/otp.module';
import { UsersModule } from '../users/users.module';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { TokensModule } from './tokens.module';

@Module({
  imports: [TokensModule, OtpModule, UsersModule],
  controllers: [AuthController],
  providers: [AuthService],
})
export class AuthModule {}
