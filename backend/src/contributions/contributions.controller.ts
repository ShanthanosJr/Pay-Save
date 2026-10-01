import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Res,
  UseGuards,
} from '@nestjs/common';
import type { Response } from 'express';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CircleRole, CurrentMembership } from '../circles/circle-role.guard';
import type { Membership } from '../circles/circle-role.guard';
import { ContributionsService } from './contributions.service';
import {
  RecordContributionDto,
  RejectContributionDto,
} from './dto/contributions.dto';

@Controller('circles/:id')
@UseGuards(JwtAuthGuard)
export class ContributionsController {
  constructor(private readonly contributions: ContributionsService) {}

  @Post('contributions')
  @CircleRole('member')
  async record(
    @CurrentMembership() m: Membership,
    @Body() dto: RecordContributionDto,
    @Res({ passthrough: true }) res: Response,
  ) {
    const { entry, created } = await this.contributions.record(m, dto);
    res.status(created ? 201 : 200);
    return { entry };
  }

  @Post('contributions/:entryId/verify')
  @CircleRole('organizer')
  verify(@CurrentMembership() m: Membership, @Param('entryId') id: string) {
    return this.contributions.verify(m, id);
  }

  @Post('contributions/:entryId/reject')
  @CircleRole('organizer')
  reject(
    @CurrentMembership() m: Membership,
    @Param('entryId') id: string,
    @Body() dto: RejectContributionDto,
  ) {
    return this.contributions.reject(m, id, dto.reason);
  }

  @Get('verify-queue')
  @CircleRole('organizer')
  verifyQueue(@CurrentMembership() m: Membership) {
    return this.contributions.verifyQueue(m);
  }
}
