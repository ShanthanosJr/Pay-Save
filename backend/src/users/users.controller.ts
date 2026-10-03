import {
  Body,
  CallHandler,
  Controller,
  Delete,
  Get,
  ExecutionContext,
  HttpCode,
  Injectable,
  Param,
  ParseUUIDPipe,
  Patch,
  PayloadTooLargeException,
  Post,
  Put,
  Res,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { Throttle } from '@nestjs/throttler';
import type { Response } from 'express';
import type { Observable } from 'rxjs';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { AuthUser } from '../auth/jwt-auth.guard';
import { AppException } from '../common/errors/app.exception';
import { MAX_AVATAR_BYTES } from './avatar.storage';
import { ChangePhoneDto, UpdateMeDto, VerifyEmailDto } from './dto/users.dto';
import { UsersService } from './users.service';

/** Multer's size-limit error, reshaped into the API's `{ code }` errors. */
@Injectable()
class AvatarUploadInterceptor extends FileInterceptor('file', {
  limits: { fileSize: MAX_AVATAR_BYTES, files: 1 },
}) {
  async intercept(
    ctx: ExecutionContext,
    next: CallHandler,
  ): Promise<Observable<unknown>> {
    try {
      return await super.intercept(ctx, next);
    } catch (err) {
      if (err instanceof PayloadTooLargeException)
        throw new AppException(413, 'IMAGE_TOO_LARGE', 'Photo is too large');
      throw err;
    }
  }
}

@Controller('users/me')
@UseGuards(JwtAuthGuard)
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get()
  me(@CurrentUser() user: AuthUser) {
    return this.users.me(user.id);
  }

  @Patch()
  update(@CurrentUser() user: AuthUser, @Body() dto: UpdateMeDto) {
    return this.users.updateProfile(user.id, dto);
  }

  @Post('phone')
  @HttpCode(200)
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  changePhone(@CurrentUser() user: AuthUser, @Body() dto: ChangePhoneDto) {
    return this.users.changePhone(
      user.id,
      dto.phone,
      dto.phoneVerificationToken,
    );
  }

  @Put('avatar')
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @UseInterceptors(AvatarUploadInterceptor)
  setAvatar(
    @CurrentUser() user: AuthUser,
    @UploadedFile() file: Express.Multer.File | undefined,
  ) {
    return this.users.setAvatar(user.id, file?.buffer);
  }

  @Delete('avatar')
  removeAvatar(@CurrentUser() user: AuthUser) {
    return this.users.removeAvatar(user.id);
  }

  @Post('email/otp')
  @HttpCode(200)
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  requestEmailOtp(@CurrentUser() user: AuthUser) {
    return this.users.requestEmailOtp(user.id);
  }

  @Post('email/verify')
  @HttpCode(200)
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  verifyEmail(@CurrentUser() user: AuthUser, @Body() dto: VerifyEmailDto) {
    return this.users.verifyEmail(user.id, dto.code);
  }
}

/** Profile photos are visible to every signed-in user (never anonymously). */
@Controller('users/:id/avatar')
@UseGuards(JwtAuthGuard)
@Throttle({ default: { limit: 300, ttl: 60_000 } })
export class AvatarController {
  constructor(private readonly users: UsersService) {}

  @Get()
  async get(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Res() res: Response,
  ): Promise<void> {
    const avatar = await this.users.avatar(id);
    res
      .status(200)
      .set({
        'Content-Type': avatar.contentType,
        'Content-Length': String(avatar.data.length),
        // the URL carries ?v=<updatedAt>, so a new photo is a new URL
        'Cache-Control': 'private, max-age=31536000, immutable',
        'X-Content-Type-Options': 'nosniff',
        'Content-Security-Policy': "default-src 'none'",
      })
      .end(avatar.data);
  }
}
