import { Module } from '@nestjs/common';
import { TokensModule } from '../auth/tokens.module';
import { MemberOnlyGuard } from './social-access.guard';
import { ChatsController, PeopleController } from './social.controller';
import { SocialRepository } from './social.repository';
import { SocialService } from './social.service';

@Module({
  imports: [TokensModule],
  controllers: [PeopleController, ChatsController],
  providers: [SocialRepository, SocialService, MemberOnlyGuard],
})
export class SocialModule {}
