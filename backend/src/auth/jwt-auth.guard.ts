import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import type { Request } from 'express';
import { AppException } from '../common/errors/app.exception';
import { TokenService } from './token.service';

export interface AuthUser {
  id: string;
}

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(private readonly tokens: TokenService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context
      .switchToHttp()
      .getRequest<Request & { user?: AuthUser }>();
    const header = req.headers.authorization ?? '';
    const [scheme, token] = header.split(' ');
    const userId =
      scheme === 'Bearer' && token
        ? await this.tokens.verifyAccess(token)
        : null;
    if (!userId) throw new AppException(401, 'UNAUTHORIZED', 'Unauthorized');
    req.user = { id: userId };
    return true;
  }
}
