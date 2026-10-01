import {
  applyDecorators,
  CanActivate,
  createParamDecorator,
  ExecutionContext,
  Inject,
  Injectable,
  SetMetadata,
  UseGuards,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import type { Request } from 'express';
import { Pool } from 'pg';
import type { AuthUser } from '../auth/jwt-auth.guard';
import { AppException } from '../common/errors/app.exception';
import { PG_POOL } from '../database/database.module';
import { isUuid } from '../database/transaction';

export type MemberRole = 'organizer' | 'member';

export interface Membership {
  circleId: string;
  userId: string;
  role: MemberRole;
}

const CIRCLE_ROLE = 'circleRole';

type CircleRequest = Request & { user?: AuthUser; membership?: Membership };

export const circleNotFound = () =>
  new AppException(404, 'CIRCLE_NOT_FOUND', 'Circle not found');

export const forbiddenRole = () =>
  new AppException(403, 'FORBIDDEN_ROLE', 'Your role cannot do this');

/** Requires membership of circle `:id`; 'member' admits any member, 'organizer' only organizers. */
@Injectable()
export class CircleRoleGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    @Inject(PG_POOL) private readonly pool: Pool,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const required = this.reflector.get<MemberRole | undefined>(
      CIRCLE_ROLE,
      context.getHandler(),
    );
    if (!required) throw new Error('CircleRoleGuard used without @CircleRole');
    const req = context.switchToHttp().getRequest<CircleRequest>();
    const userId = req.user?.id;
    const circleId = String(req.params.id ?? '');
    if (!userId) throw new AppException(401, 'UNAUTHORIZED', 'Unauthorized');
    if (!isUuid(circleId)) throw circleNotFound();

    const { rows } = await this.pool.query<{ role: MemberRole }>(
      `SELECT role FROM circle_members
       WHERE circle_id = $1 AND user_id = $2 AND left_cycle IS NULL`,
      [circleId, userId],
    );
    const role = rows[0]?.role;
    if (!role) throw circleNotFound();
    if (required === 'organizer' && role !== 'organizer') throw forbiddenRole();
    req.membership = { circleId, userId, role };
    return true;
  }
}

export const CircleRole = (role: MemberRole) =>
  applyDecorators(SetMetadata(CIRCLE_ROLE, role), UseGuards(CircleRoleGuard));

export const CurrentMembership = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): Membership => {
    const m = ctx.switchToHttp().getRequest<CircleRequest>().membership;
    if (!m) throw new Error('CurrentMembership used without @CircleRole');
    return m;
  },
);
