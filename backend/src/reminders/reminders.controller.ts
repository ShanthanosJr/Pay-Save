import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Post,
  Put,
  UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsInt,
  Max,
  Min,
} from 'class-validator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CircleRole, CurrentMembership } from '../circles/circle-role.guard';
import type { Membership } from '../circles/circle-role.guard';
import { REMINDER_CHANNELS, RemindersService } from './reminders.service';
import type { ReminderChannel } from './reminders.service';

class ReminderPreferencesDto {
  @IsBoolean()
  enabled!: boolean;

  @IsArray()
  @ArrayMaxSize(4)
  @IsInt({ each: true })
  @Min(0, { each: true })
  @Max(14, { each: true })
  daysBefore!: number[];

  @IsArray()
  @ArrayMaxSize(2)
  @IsIn(REMINDER_CHANNELS, { each: true })
  channels!: ReminderChannel[];
}

@Controller('circles/:id')
@UseGuards(JwtAuthGuard)
export class RemindersController {
  constructor(private readonly reminders: RemindersService) {}

  @Get('reminders')
  @CircleRole('member')
  get(@CurrentMembership() m: Membership) {
    return this.reminders.get(m);
  }

  @Put('reminders')
  @CircleRole('member')
  set(@CurrentMembership() m: Membership, @Body() dto: ReminderPreferencesDto) {
    return this.reminders.set(m, dto);
  }

  @Post('members/:userId/remind')
  @HttpCode(200)
  @CircleRole('organizer')
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  nudge(
    @CurrentMembership() m: Membership,
    @Param('userId', new ParseUUIDPipe()) userId: string,
  ) {
    return this.reminders.nudge(m, userId);
  }
}
