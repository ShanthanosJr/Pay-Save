import { Inject, Injectable } from '@nestjs/common';
import { CLOCK } from '../common/clock/clock';
import type { Clock } from '../common/clock/clock';
import { CryptoService } from '../common/crypto/crypto.service';
import { AppException } from '../common/errors/app.exception';
import { maskNic } from '../common/normalize/nic';
import { maskPhone } from '../common/normalize/phone';
import { APP_CONFIG } from '../config/app-config';
import type { AppConfig } from '../config/app-config';
import { OtpService, otpResponse } from '../otp/otp.service';
import { Language, UserRecord, UsersRepository } from './users.repository';

export interface PublicUser {
  id: string;
  fullName: string;
  age: number | null;
  email: string | null;
  emailVerified: boolean;
  phoneMasked: string;
  phoneVerified: boolean;
  nicMasked: string | null;
  language: Language;
  createdAt: string;
}

@Injectable()
export class UsersService {
  constructor(
    private readonly users: UsersRepository,
    private readonly crypto: CryptoService,
    private readonly otp: OtpService,
    @Inject(CLOCK) private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly cfg: AppConfig,
  ) {}

  toPublic(u: UserRecord): PublicUser {
    return {
      id: u.id,
      fullName: u.fullName,
      age: u.age,
      email: u.email,
      emailVerified: u.emailVerifiedAt !== null,
      phoneMasked: maskPhone(this.crypto.decryptPii(u.phoneEncrypted, 'phone')),
      phoneVerified: u.phoneVerifiedAt !== null,
      nicMasked: u.nicEncrypted
        ? maskNic(this.crypto.decryptPii(u.nicEncrypted, 'nic'))
        : null,
      language: u.language,
      createdAt: u.createdAt.toISOString(),
    };
  }

  async getOrThrow(id: string): Promise<UserRecord> {
    const user = await this.users.findById(id);
    if (!user) throw new AppException(401, 'UNAUTHORIZED', 'Unauthorized');
    return user;
  }

  async me(id: string): Promise<PublicUser> {
    return this.toPublic(await this.getOrThrow(id));
  }

  async updateLanguage(id: string, language: Language): Promise<PublicUser> {
    await this.getOrThrow(id);
    await this.users.updateLanguage(id, language);
    return this.me(id);
  }

  async requestEmailOtp(id: string) {
    const user = await this.getOrThrow(id);
    if (!user.email)
      throw new AppException(400, 'NO_EMAIL', 'No email on this account');
    if (user.emailVerifiedAt)
      throw new AppException(
        409,
        'EMAIL_ALREADY_VERIFIED',
        'Email already verified',
      );
    return otpResponse(
      await this.otp.issue('email_verify', user.email, user.id),
      this.cfg.devOtpEcho,
    );
  }

  async verifyEmail(
    id: string,
    code: string,
  ): Promise<{ emailVerified: true }> {
    const user = await this.getOrThrow(id);
    if (!user.email)
      throw new AppException(400, 'NO_EMAIL', 'No email on this account');
    if (user.emailVerifiedAt)
      throw new AppException(
        409,
        'EMAIL_ALREADY_VERIFIED',
        'Email already verified',
      );
    await this.otp.verify('email_verify', user.email, code);
    await this.users.markEmailVerified(id, this.clock.now());
    return { emailVerified: true };
  }
}
