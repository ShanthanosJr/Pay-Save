import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Post,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { AuthUser } from '../auth/jwt-auth.guard';
import {
  MessagesQueryDto,
  OpenChatDto,
  SearchQueryDto,
  SendMessageDto,
} from './dto/social.dto';
import { MemberOnlyGuard } from './social-access.guard';
import { SocialService } from './social.service';

const uuid = new ParseUUIDPipe();

@Controller('people')
@UseGuards(JwtAuthGuard, MemberOnlyGuard)
@Throttle({ default: { limit: 120, ttl: 60_000 } })
export class PeopleController {
  constructor(private readonly social: SocialService) {}

  @Get('search')
  search(@CurrentUser() me: AuthUser, @Query() dto: SearchQueryDto) {
    return this.social.search(me.id, dto.q);
  }

  @Get('pal-requests')
  palRequests(@CurrentUser() me: AuthUser) {
    return this.social.palRequests(me.id);
  }

  @Get('pal-requests/count')
  palRequestCount(@CurrentUser() me: AuthUser) {
    return this.social.palRequestCount(me.id);
  }

  @Get('suggestions')
  suggestions(@CurrentUser() me: AuthUser) {
    return this.social.suggestions(me.id);
  }

  @Get(':id')
  profile(@CurrentUser() me: AuthUser, @Param('id', uuid) id: string) {
    return this.social.profile(me.id, id);
  }

  @Get(':id/followers')
  followers(@CurrentUser() me: AuthUser, @Param('id', uuid) id: string) {
    return this.social.followers(me.id, id);
  }

  @Get(':id/following')
  following(@CurrentUser() me: AuthUser, @Param('id', uuid) id: string) {
    return this.social.following(me.id, id);
  }

  @Get(':id/pals')
  pals(@CurrentUser() me: AuthUser, @Param('id', uuid) id: string) {
    return this.social.pals(me.id, id);
  }

  /** Sends a pal request (or accepts theirs if they already asked). */
  @Put(':id/pal')
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  requestPal(@CurrentUser() me: AuthUser, @Param('id', uuid) id: string) {
    return this.social.requestPal(me.id, id);
  }

  /** Withdraws my request or removes the pal. */
  @Delete(':id/pal')
  endPal(@CurrentUser() me: AuthUser, @Param('id', uuid) id: string) {
    return this.social.endPal(me.id, id);
  }

  @Post(':id/pal/accept')
  @HttpCode(200)
  acceptPal(@CurrentUser() me: AuthUser, @Param('id', uuid) id: string) {
    return this.social.acceptPal(me.id, id);
  }

  @Post(':id/pal/ignore')
  @HttpCode(200)
  ignorePal(@CurrentUser() me: AuthUser, @Param('id', uuid) id: string) {
    return this.social.ignorePal(me.id, id);
  }

  @Put(':id/follow')
  follow(@CurrentUser() me: AuthUser, @Param('id', uuid) id: string) {
    return this.social.follow(me.id, id);
  }

  @Delete(':id/follow')
  unfollow(@CurrentUser() me: AuthUser, @Param('id', uuid) id: string) {
    return this.social.unfollow(me.id, id);
  }

  @Put(':id/block')
  @HttpCode(204)
  async block(@CurrentUser() me: AuthUser, @Param('id', uuid) id: string) {
    await this.social.block(me.id, id);
  }

  @Delete(':id/block')
  @HttpCode(204)
  async unblock(@CurrentUser() me: AuthUser, @Param('id', uuid) id: string) {
    await this.social.unblock(me.id, id);
  }
}

/** Polled by the app (no socket yet), hence the higher rate limit. */
@Controller('chats')
@UseGuards(JwtAuthGuard, MemberOnlyGuard)
@Throttle({ default: { limit: 240, ttl: 60_000 } })
export class ChatsController {
  constructor(private readonly social: SocialService) {}

  @Get()
  inbox(@CurrentUser() me: AuthUser) {
    return this.social.inbox(me.id);
  }

  @Get('unread')
  unread(@CurrentUser() me: AuthUser) {
    return this.social.unreadTotal(me.id);
  }

  @Post()
  @HttpCode(200)
  open(@CurrentUser() me: AuthUser, @Body() dto: OpenChatDto) {
    return this.social.open(me.id, dto.userId);
  }

  @Get(':id')
  thread(@CurrentUser() me: AuthUser, @Param('id', uuid) id: string) {
    return this.social.thread(me.id, id);
  }

  @Get(':id/messages')
  messages(
    @CurrentUser() me: AuthUser,
    @Param('id', uuid) id: string,
    @Query() page: MessagesQueryDto,
  ) {
    return this.social.messages(me.id, id, page);
  }

  @Post(':id/messages')
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  send(
    @CurrentUser() me: AuthUser,
    @Param('id', uuid) id: string,
    @Body() dto: SendMessageDto,
  ) {
    return this.social.send(me.id, id, dto.clientMessageId, dto.body);
  }

  @Post(':id/read')
  @HttpCode(200)
  read(@CurrentUser() me: AuthUser, @Param('id', uuid) id: string) {
    return this.social.markRead(me.id, id);
  }
}
