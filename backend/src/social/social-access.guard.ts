import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import type { AuthUser } from '../auth/jwt-auth.guard';
import { AppException } from '../common/errors/app.exception';
import { SocialRepository } from './social.repository';

/**
 * People and chat are member features. Community officers never receive
 * member names (AGENTS.md rule 9), so they are refused here. Runs after
 * JwtAuthGuard.
 */
@Injectable()
export class MemberOnlyGuard implements CanActivate {
  constructor(private readonly repo: SocialRepository) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const { user } = context.switchToHttp().getRequest<{ user: AuthUser }>();
    if (await this.repo.isCommunityOfficer(user.id))
      throw new AppException(
        403,
        'FORBIDDEN',
        'Not available to community officers',
      );
    return true;
  }
}
