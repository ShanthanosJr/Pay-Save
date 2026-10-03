import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { AuthUser } from '../auth/jwt-auth.guard';
import { CircleRole, CurrentMembership } from './circle-role.guard';
import type { Membership } from './circle-role.guard';
import { CirclesService } from './circles.service';
import {
  CloseCycleDto,
  CreateCircleDto,
  JoinCircleDto,
  LedgerQueryDto,
  StartCircleDto,
} from './dto/circles.dto';

@Controller('circles')
@UseGuards(JwtAuthGuard)
export class CirclesController {
  constructor(private readonly circles: CirclesService) {}

  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateCircleDto) {
    return this.circles.create(user.id, dto);
  }

  @Get()
  list(@CurrentUser() user: AuthUser) {
    return this.circles.list(user.id);
  }

  @Post('join')
  @HttpCode(200)
  join(@CurrentUser() user: AuthUser, @Body() dto: JoinCircleDto) {
    return this.circles.join(user.id, dto.code);
  }

  @Get(':id')
  @CircleRole('member')
  get(@CurrentMembership() m: Membership) {
    return this.circles.get(m);
  }

  @Post(':id/lottery/commit')
  @HttpCode(200)
  @CircleRole('organizer')
  commitLottery(@CurrentMembership() m: Membership) {
    return this.circles.commitLottery(m);
  }

  @Post(':id/start')
  @HttpCode(200)
  @CircleRole('organizer')
  start(@CurrentMembership() m: Membership, @Body() dto: StartCircleDto) {
    return this.circles.start(m, dto.order);
  }

  @Post(':id/cycles/:n/close')
  @HttpCode(200)
  @CircleRole('organizer')
  close(
    @CurrentMembership() m: Membership,
    @Param('n') n: string,
    @Body() dto: CloseCycleDto,
  ) {
    return this.circles.closeCycle(m, n, dto.acknowledgeUnpaid);
  }

  @Get(':id/ledger')
  @CircleRole('member')
  ledger(@CurrentMembership() m: Membership, @Query() q: LedgerQueryDto) {
    return this.circles.ledgerEntries(m, q.scope);
  }
}
