import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Post,
  UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { AuthUser } from '../auth/jwt-auth.guard';
import { AddPayoutMethodDto } from './dto/payouts.dto';
import { PayoutsService } from './payouts.service';

/** "How I get paid": the member's own payment details. */
@Controller('users/me/payout-methods')
@UseGuards(JwtAuthGuard)
export class PayoutsController {
  constructor(private readonly payouts: PayoutsService) {}

  @Get()
  list(@CurrentUser() me: AuthUser) {
    return this.payouts.listMine(me.id);
  }

  @Post()
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  add(@CurrentUser() me: AuthUser, @Body() dto: AddPayoutMethodDto) {
    return this.payouts.add(me.id, dto);
  }

  @Post(':methodId/default')
  @HttpCode(200)
  makeDefault(
    @CurrentUser() me: AuthUser,
    @Param('methodId', new ParseUUIDPipe()) methodId: string,
  ) {
    return this.payouts.makeDefault(me.id, methodId);
  }

  @Delete(':methodId')
  remove(
    @CurrentUser() me: AuthUser,
    @Param('methodId', new ParseUUIDPipe()) methodId: string,
  ) {
    return this.payouts.remove(me.id, methodId);
  }
}
