import { Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import {
  InjectThrottlerOptions,
  InjectThrottlerStorage,
  ThrottlerGuard,
} from '@nestjs/throttler';
import type {
  ThrottlerModuleOptions,
  ThrottlerStorage,
} from '@nestjs/throttler';
import type { Request } from 'express';
import { TokenService } from '../auth/token.service';

/**
 * Buckets signed-in traffic per user rather than per IP: Sri Lankan mobile
 * carriers put many subscribers behind one carrier-NAT address. Auth routes
 * stay per IP so a valid token cannot widen the login/OTP limits.
 */
@Injectable()
export class UserThrottlerGuard extends ThrottlerGuard {
  constructor(
    @InjectThrottlerOptions() options: ThrottlerModuleOptions,
    @InjectThrottlerStorage() storage: ThrottlerStorage,
    reflector: Reflector,
    private readonly tokens: TokenService,
  ) {
    super(options, storage, reflector);
  }

  protected override async getTracker(
    req: Record<string, unknown>,
  ): Promise<string> {
    const r = req as unknown as Request;
    const ip = r.ip ?? r.socket?.remoteAddress ?? 'unknown';
    if (r.path?.startsWith('/auth/')) return `ip:${ip}`;
    const [scheme, token] = (r.headers?.authorization ?? '').split(' ');
    if (scheme === 'Bearer' && token) {
      const userId = await this.tokens.verifyAccess(token);
      if (userId) return `user:${userId}`;
    }
    return `ip:${ip}`;
  }
}
