import { Inject, Injectable } from '@nestjs/common';
import { TokenService } from '../auth/token.service';
import { CLOCK } from '../common/clock/clock';
import type { Clock } from '../common/clock/clock';
import { CryptoService } from '../common/crypto/crypto.service';
import { AppException } from '../common/errors/app.exception';
import { maskNic } from '../common/normalize/nic';
import { safeEqual } from '../common/crypto/hash';
import { maskPhone, normalizePhone } from '../common/normalize/phone';
import { APP_CONFIG } from '../config/app-config';
import type { AppConfig } from '../config/app-config';
import { OtpService, otpResponse } from '../otp/otp.service';
import {
  AVATAR_STORAGE,
  MAX_AVATAR_BYTES,
  StoredAvatar,
} from './avatar.storage';
import type { AvatarStorage } from './avatar.storage';
import { avatarUrl, sniffImageType } from './image-type';
import { UserRecord, UsersRepository } from './users.repository';
import type { Language, ProfilePatch } from './users.repository';

export interface ProfileUpdate {
  fullName?: string;
  age?: number;
  username?: string;
  bio?: string;
  city?: string;
  language?: Language;
}

const isUniqueViolation = (err: unknown, constraint: string): boolean =>
  (err as { code?: string }).code === '23505' &&
  (err as { constraint?: string }).constraint === constraint;

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
  username: string | null;
  bio: string | null;
  city: string | null;
  avatarUrl: string | null;
  createdAt: string;
}

@Injectable()
export class UsersService {
  constructor(
    private readonly users: UsersRepository,
    private readonly crypto: CryptoService,
    private readonly otp: OtpService,
    private readonly tokens: TokenService,
    @Inject(AVATAR_STORAGE) private readonly avatars: AvatarStorage,
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
      username: u.username,
      bio: u.bio,
      city: u.city,
      avatarUrl: avatarUrl(u.id, u.avatarUpdatedAt),
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

  async updateProfile(id: string, input: ProfileUpdate): Promise<PublicUser> {
    await this.getOrThrow(id);
    const blankToNull = (v: string | undefined) =>
      v === undefined ? undefined : v === '' ? null : v;
    const patch: ProfilePatch = {
      fullName: input.fullName,
      age: input.age,
      language: input.language,
      username: blankToNull(input.username),
      bio: blankToNull(input.bio),
      city: blankToNull(input.city),
    };
    try {
      await this.users.updateProfile(id, patch);
    } catch (err) {
      if (isUniqueViolation(err, 'users_username_key'))
        throw new AppException(409, 'USERNAME_TAKEN', 'Username is taken');
      throw err;
    }
    return this.me(id);
  }

  /**
   * The new number must have been verified through /auth/otp/request and
   * /auth/otp/verify first; the resulting token proves the user holds it.
   */
  async changePhone(
    id: string,
    phoneInput: string,
    phoneVerificationToken: string,
  ): Promise<PublicUser> {
    const user = await this.getOrThrow(id);
    const phone = normalizePhone(phoneInput);
    const phoneHash = this.crypto.lookupHash(phone);
    const tokenHash = await this.tokens.verifyPhoneVerified(
      phoneVerificationToken,
    );
    if (!tokenHash || !safeEqual(tokenHash, phoneHash)) {
      throw new AppException(
        400,
        'INVALID_VERIFICATION_TOKEN',
        'Phone verification is invalid or expired',
      );
    }
    if (user.phoneHash === phoneHash) return this.toPublic(user);
    try {
      await this.users.updatePhone(
        id,
        this.crypto.encryptPii(phone, 'phone'),
        phoneHash,
        this.clock.now(),
      );
    } catch (err) {
      if (isUniqueViolation(err, 'users_phone_hash_key'))
        throw new AppException(
          409,
          'PHONE_TAKEN',
          'Phone number already registered',
        );
      throw err;
    }
    return this.me(id);
  }

  async setAvatar(id: string, file: Buffer | undefined): Promise<PublicUser> {
    await this.getOrThrow(id);
    if (!file || file.length === 0)
      throw new AppException(400, 'IMAGE_REQUIRED', 'Choose a photo');
    if (file.length > MAX_AVATAR_BYTES)
      throw new AppException(413, 'IMAGE_TOO_LARGE', 'Photo is too large');
    const type = sniffImageType(file);
    if (!type)
      throw new AppException(
        415,
        'UNSUPPORTED_IMAGE',
        'Use a JPEG, PNG or WebP photo',
      );
    await this.avatars.put(id, type, file, this.clock.now());
    return this.me(id);
  }

  async removeAvatar(id: string): Promise<PublicUser> {
    await this.getOrThrow(id);
    await this.avatars.remove(id);
    return this.me(id);
  }

  async avatar(userId: string): Promise<StoredAvatar> {
    const found = await this.avatars.get(userId);
    if (!found) throw new AppException(404, 'NOT_FOUND', 'No photo');
    return found;
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
