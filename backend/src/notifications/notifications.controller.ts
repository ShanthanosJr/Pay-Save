import {
  Body,
  Controller,
  Get,
  HttpCode,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsInt,
  IsOptional,
  IsUUID,
  Max,
  Min,
} from 'class-validator';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { AuthUser } from '../auth/jwt-auth.guard';
import { NotificationsService } from './notifications.service';

class ListQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;
}

class MarkReadDto {
  /** Omit to mark everything read. */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(100)
  @IsUUID('all', { each: true })
  ids?: string[];
}

/** Only ever the signed-in user's own inbox; no circle role applies. */
@Controller('notifications')
@UseGuards(JwtAuthGuard)
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Get()
  list(@CurrentUser() user: AuthUser, @Query() q: ListQueryDto) {
    return this.notifications.list(user.id, q.limit ?? 50);
  }

  @Get('unread')
  async unread(@CurrentUser() user: AuthUser) {
    return { unread: await this.notifications.unread(user.id) };
  }

  @Post('read')
  @HttpCode(200)
  read(@CurrentUser() user: AuthUser, @Body() dto: MarkReadDto) {
    return this.notifications.markRead(user.id, dto.ids);
  }
}
