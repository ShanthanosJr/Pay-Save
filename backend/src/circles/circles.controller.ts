import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { SharePayoutMethodsDto } from '../payouts/dto/payouts.dto';
import { CircleInvitationsService } from './circle-invitations.service';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { AuthUser } from '../auth/jwt-auth.guard';
import { CircleRole, CurrentMembership } from './circle-role.guard';
import type { Membership } from './circle-role.guard';
import { CirclesService } from './circles.service';
import {
  AcceptInvitationDto,
  CircleSettingsDto,
  CloseCycleDto,
  InvitePalsDto,
  CreateCircleDto,
  JoinCircleDto,
  LedgerQueryDto,
  RemoveMemberDto,
  StartCircleDto,
} from './dto/circles.dto';

@Controller('circles')
@UseGuards(JwtAuthGuard)
export class CirclesController {
  constructor(
    private readonly circles: CirclesService,
    private readonly invitations: CircleInvitationsService,
  ) {}

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

  @Patch(':id')
  @CircleRole('organizer')
  settings(@CurrentMembership() m: Membership, @Body() dto: CircleSettingsDto) {
    return this.circles.updateSettings(m, dto.collectionMode);
  }

  /** Which of my payment methods this circle may see. */
  @Put(':id/payout-methods')
  @CircleRole('member')
  sharePayout(
    @CurrentMembership() m: Membership,
    @Body() dto: SharePayoutMethodsDto,
  ) {
    return this.circles.sharePayout(m, dto.methodIds, dto.preferredId);
  }

  /** Who I pay this cycle, with their payment details (logged). */
  @Get(':id/pay-to')
  @CircleRole('member')
  payTo(@CurrentMembership() m: Membership) {
    return this.circles.payTo(m);
  }

  @Get(':id/invitable-pals')
  @CircleRole('organizer')
  invitable(@CurrentMembership() m: Membership) {
    return this.invitations.invitable(m);
  }

  @Post(':id/invitations')
  @CircleRole('organizer')
  invite(@CurrentMembership() m: Membership, @Body() dto: InvitePalsDto) {
    return this.invitations.invite(m, dto.userIds, dto.message);
  }

  @Delete(':id/invitations/:invitationId')
  @CircleRole('organizer')
  cancelInvitation(
    @CurrentMembership() m: Membership,
    @Param('invitationId', new ParseUUIDPipe()) invitationId: string,
  ) {
    return this.invitations.cancel(m, invitationId);
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

  @Post(':id/leave')
  @HttpCode(204)
  @CircleRole('member')
  async leave(@CurrentMembership() m: Membership): Promise<void> {
    await this.circles.leave(m);
  }

  @Post(':id/members/:userId/remove')
  @HttpCode(200)
  @CircleRole('organizer')
  removeMember(
    @CurrentMembership() m: Membership,
    @Param('userId', new ParseUUIDPipe()) userId: string,
    @Body() dto: RemoveMemberDto,
  ) {
    return this.circles.removeMember(m, userId, dto.reason);
  }

  @Get(':id/ledger')
  @CircleRole('member')
  ledger(@CurrentMembership() m: Membership, @Query() q: LedgerQueryDto) {
    return this.circles.ledgerEntries(m, q.scope);
  }
}

/** Invitations addressed to the signed-in member. */
@Controller('circle-invitations')
@UseGuards(JwtAuthGuard)
export class CircleInvitationsController {
  constructor(private readonly invitations: CircleInvitationsService) {}

  @Get()
  mine(@CurrentUser() user: AuthUser) {
    return this.invitations.mine(user.id);
  }

  @Post(':invitationId/accept')
  @HttpCode(200)
  accept(
    @CurrentUser() user: AuthUser,
    @Param('invitationId', new ParseUUIDPipe()) invitationId: string,
    @Body() dto: AcceptInvitationDto,
  ) {
    return this.invitations.accept(user.id, invitationId, dto);
  }

  @Post(':invitationId/decline')
  @HttpCode(204)
  async decline(
    @CurrentUser() user: AuthUser,
    @Param('invitationId', new ParseUUIDPipe()) invitationId: string,
  ): Promise<void> {
    await this.invitations.decline(user.id, invitationId);
  }
}
