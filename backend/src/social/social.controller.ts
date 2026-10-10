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
  Patch,
  Res,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { AuthUser } from '../auth/jwt-auth.guard';
import {
  ChatFlagsDto,
  MessagesQueryDto,
  ReactionDto,
  SendMediaDto,
  StarDto,
  OpenChatDto,
  SearchQueryDto,
  SendMessageDto,
} from './dto/social.dto';
import { MemberOnlyGuard } from './social-access.guard';
import { MAX_VIDEO_BYTES, SocialService } from './social.service';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Response } from 'express';

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

  /** A photo or short video with an optional caption. */
  @Post(':id/media')
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: MAX_VIDEO_BYTES, files: 1 },
    }),
  )
  sendMedia(
    @CurrentUser() me: AuthUser,
    @Param('id', uuid) id: string,
    @Body() dto: SendMediaDto,
    @UploadedFile() file: Express.Multer.File | undefined,
  ) {
    return this.social.sendMedia(
      me.id,
      id,
      dto.clientMessageId,
      dto.caption ?? '',
      file?.buffer,
    );
  }

  /** Participants only; never cached by anything shared. */
  @Get(':id/messages/:messageId/media')
  async media(
    @CurrentUser() me: AuthUser,
    @Param('id', uuid) id: string,
    @Param('messageId', uuid) messageId: string,
    @Res() res: Response,
  ): Promise<void> {
    const m = await this.social.media(me.id, id, messageId);
    res
      .status(200)
      .set({
        'Content-Type': m.contentType,
        'Content-Length': String(m.data.length),
        'Cache-Control': 'private, max-age=86400',
        'X-Content-Type-Options': 'nosniff',
        'Content-Security-Policy': "default-src 'none'",
      })
      .end(m.data);
  }

  @Delete(':id/messages/:messageId')
  @HttpCode(204)
  async deleteMessage(
    @CurrentUser() me: AuthUser,
    @Param('id', uuid) id: string,
    @Param('messageId', uuid) messageId: string,
  ): Promise<void> {
    await this.social.deleteMessage(me.id, id, messageId);
  }

  @Put(':id/messages/:messageId/reaction')
  react(
    @CurrentUser() me: AuthUser,
    @Param('id', uuid) id: string,
    @Param('messageId', uuid) messageId: string,
    @Body() dto: ReactionDto,
  ) {
    return this.social.react(me.id, id, messageId, dto.emoji);
  }

  @Put(':id/messages/:messageId/star')
  star(
    @CurrentUser() me: AuthUser,
    @Param('id', uuid) id: string,
    @Param('messageId', uuid) messageId: string,
    @Body() dto: StarDto,
  ) {
    return this.social.star(me.id, id, messageId, dto.starred);
  }

  /** Pin or favourite a chat, for me only. */
  @Patch(':id')
  @HttpCode(204)
  async flags(
    @CurrentUser() me: AuthUser,
    @Param('id', uuid) id: string,
    @Body() dto: ChatFlagsDto,
  ): Promise<void> {
    await this.social.setChatFlags(me.id, id, dto);
  }

  /** Delete the chat from my inbox; the other person keeps their copy. */
  @Delete(':id')
  @HttpCode(204)
  async clear(
    @CurrentUser() me: AuthUser,
    @Param('id', uuid) id: string,
  ): Promise<void> {
    await this.social.clearChat(me.id, id);
  }

  @Post(':id/read')
  @HttpCode(200)
  read(@CurrentUser() me: AuthUser, @Param('id', uuid) id: string) {
    return this.social.markRead(me.id, id);
  }
}
