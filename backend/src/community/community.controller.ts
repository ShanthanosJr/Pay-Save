import {
  Body,
  CanActivate,
  Controller,
  ExecutionContext,
  Get,
  HttpCode,
  Inject,
  Injectable,
  Param,
  ParseUUIDPipe,
  Post,
  Put,
  UseGuards,
} from '@nestjs/common';
import { Transform } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsString,
  IsUUID,
  Length,
} from 'class-validator';
import { Pool } from 'pg';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { AuthUser } from '../auth/jwt-auth.guard';
import { CircleRole, CurrentMembership } from '../circles/circle-role.guard';
import type { Membership } from '../circles/circle-role.guard';
import { AppException } from '../common/errors/app.exception';
import { PG_POOL } from '../database/database.module';
import { CommunityService, DISPUTE_CATEGORIES } from './community.service';
import type { DisputeCategory } from './community.service';

class ConsentDto {
  @IsBoolean()
  granted!: boolean;
}

class RaiseDisputeDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(10)
  @IsUUID('all', { each: true })
  entryIds!: string[];

  @IsIn(DISPUTE_CATEGORIES)
  category!: DisputeCategory;
}

class ResolveDto {
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  @IsString()
  @Length(3, 500)
  note!: string;
}

/** The community-officer role is global, not per circle. Runs after JwtAuthGuard. */
@Injectable()
export class OfficerGuard implements CanActivate {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const { user } = context.switchToHttp().getRequest<{ user: AuthUser }>();
    const { rows } = await this.pool.query<{ officer: boolean }>(
      'SELECT is_community_officer AS officer FROM users WHERE id = $1',
      [user.id],
    );
    if (!rows[0]?.officer)
      throw new AppException(403, 'FORBIDDEN', 'Community officers only');
    return true;
  }
}

/** What members decide about sharing with the community tier. */
@Controller('circles/:id')
@UseGuards(JwtAuthGuard)
export class CircleCommunityController {
  constructor(private readonly community: CommunityService) {}

  @Get('community')
  @CircleRole('member')
  consent(@CurrentMembership() m: Membership) {
    return this.community.consent(m);
  }

  @Put('community/consent')
  @CircleRole('member')
  setConsent(@CurrentMembership() m: Membership, @Body() dto: ConsentDto) {
    return this.community.setConsent(m, dto.granted);
  }

  @Get('disputes')
  @CircleRole('member')
  disputes(@CurrentMembership() m: Membership) {
    return this.community.disputes(m);
  }

  @Post('disputes')
  @CircleRole('member')
  raise(@CurrentMembership() m: Membership, @Body() dto: RaiseDisputeDto) {
    return this.community.raise(m, dto.entryIds, dto.category);
  }

  @Put('disputes/:disputeId/consent')
  @CircleRole('member')
  respond(
    @CurrentMembership() m: Membership,
    @Param('disputeId', new ParseUUIDPipe()) disputeId: string,
    @Body() dto: ConsentDto,
  ) {
    return this.community.respond(m, disputeId, dto.granted);
  }
}

/** Officers get codes, counts and consented evidence; never a name or phone. */
@Controller('community')
@UseGuards(JwtAuthGuard, OfficerGuard)
export class CommunityController {
  constructor(private readonly community: CommunityService) {}

  @Get('overview')
  overview() {
    return this.community.overview();
  }

  @Get('disputes')
  disputes() {
    return this.community.officerDisputes();
  }

  @Get('disputes/:disputeId/evidence')
  evidence(
    @CurrentUser() user: AuthUser,
    @Param('disputeId', new ParseUUIDPipe()) disputeId: string,
  ) {
    return this.community.evidence(user.id, disputeId);
  }

  @Post('disputes/:disputeId/resolve')
  @HttpCode(204)
  async resolve(
    @Param('disputeId', new ParseUUIDPipe()) disputeId: string,
    @Body() dto: ResolveDto,
  ): Promise<void> {
    await this.community.resolve(disputeId, dto.note);
  }
}
