import { Module } from '@nestjs/common';
import { TokensModule } from '../auth/tokens.module';
import { CirclesModule } from '../circles/circles.module';
import {
  CircleCommunityController,
  CommunityController,
  OfficerGuard,
} from './community.controller';
import { CommunityService } from './community.service';

@Module({
  imports: [TokensModule, CirclesModule],
  controllers: [CircleCommunityController, CommunityController],
  providers: [CommunityService, OfficerGuard],
})
export class CommunityModule {}
