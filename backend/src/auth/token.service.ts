import { Inject, Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { randomUUID } from 'node:crypto';
import { APP_CONFIG } from '../config/app-config';
import type { AppConfig } from '../config/app-config';

export const ACCESS_TTL_SECONDS = 15 * 60;
export const REFRESH_TTL_SECONDS = 30 * 24 * 60 * 60;
export const PHONE_TOKEN_TTL_SECONDS = 15 * 60;

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
}

@Injectable()
export class TokenService {
  constructor(
    private readonly jwt: JwtService,
    @Inject(APP_CONFIG) private readonly cfg: AppConfig,
  ) {}

  async issuePair(userId: string): Promise<TokenPair> {
    const [accessToken, refreshToken] = await Promise.all([
      this.jwt.signAsync(
        { sub: userId, typ: 'access' },
        { secret: this.cfg.jwtAccessSecret, expiresIn: ACCESS_TTL_SECONDS },
      ),
      this.jwt.signAsync(
        { sub: userId, typ: 'refresh', jti: randomUUID() },
        { secret: this.cfg.jwtRefreshSecret, expiresIn: REFRESH_TTL_SECONDS },
      ),
    ]);
    return { accessToken, refreshToken };
  }

  async verifyAccess(token: string): Promise<string | null> {
    return this.verifySub(token, this.cfg.jwtAccessSecret, 'access');
  }

  async verifyRefresh(token: string): Promise<string | null> {
    return this.verifySub(token, this.cfg.jwtRefreshSecret, 'refresh');
  }

  signPhoneVerified(phoneHash: string): Promise<string> {
    return this.jwt.signAsync(
      { typ: 'phone_verified', purpose: 'phone_verified', ph: phoneHash },
      { secret: this.cfg.jwtAccessSecret, expiresIn: PHONE_TOKEN_TTL_SECONDS },
    );
  }

  async verifyPhoneVerified(token: string): Promise<string | null> {
    try {
      const p = await this.jwt.verifyAsync<{
        typ?: string;
        purpose?: string;
        ph?: string;
      }>(token, {
        secret: this.cfg.jwtAccessSecret,
      });
      return p.typ === 'phone_verified' &&
        p.purpose === 'phone_verified' &&
        p.ph
        ? p.ph
        : null;
    } catch {
      return null;
    }
  }

  private async verifySub(
    token: string,
    secret: string,
    typ: string,
  ): Promise<string | null> {
    try {
      const p = await this.jwt.verifyAsync<{ sub?: string; typ?: string }>(
        token,
        { secret },
      );
      return p.typ === typ && p.sub ? p.sub : null;
    } catch {
      return null;
    }
  }
}
