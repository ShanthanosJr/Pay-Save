import { Module } from '@nestjs/common';
import { TokensModule } from '../auth/tokens.module';
import { OtpModule } from '../otp/otp.module';
import { AVATAR_STORAGE, PgAvatarStorage } from './avatar.storage';
import { AvatarController, UsersController } from './users.controller';
import { UsersRepository } from './users.repository';
import { UsersService } from './users.service';

@Module({
  imports: [TokensModule, OtpModule],
  controllers: [UsersController, AvatarController],
  providers: [
    UsersRepository,
    UsersService,
    { provide: AVATAR_STORAGE, useClass: PgAvatarStorage },
  ],
  exports: [UsersRepository, UsersService],
})
export class UsersModule {}
