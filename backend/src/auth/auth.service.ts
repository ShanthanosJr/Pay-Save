import { Inject, Injectable, OnModuleInit } from '@nestjs/common';
import { randomBytes } from 'node:crypto';
import { CLOCK } from '../common/clock/clock';
import type { Clock } from '../common/clock/clock';
import { CryptoService } from '../common/crypto/crypto.service';
import { safeEqual } from '../common/crypto/hash';
import { AppException } from '../common/errors/app.exception';
import { normalizeEmail } from '../common/normalize/email';
import { normalizeNic } from '../common/normalize/nic';
import { normalizePhone, tryNormalizePhone } from '../common/normalize/phone';
import { APP_CONFIG } from '../config/app-config';
import type { AppConfig } from '../config/app-config';
import {
  OTP_RESEND_SECONDS,
  OTP_TTL_SECONDS,
  OtpService,
  otpResponse,
} from '../otp/otp.service';
import type { OtpLanguage } from '../otp/otp-sender';
import { UserRecord, UsersRepository } from '../users/users.repository';
import { PublicUser, UsersService } from '../users/users.service';
import { TokenPair, TokenService } from './token.service';

export const MAX_LOGIN_FAILURES = 5;
export const LOCK_MINUTES = 15;

export interface RegisterInput {
  fullName: string;
  age: number;
  nic: string;
  phone: string;
  email: string;
  password: string;
  phoneVerificationToken: string;
}

export interface AuthResult extends TokenPair {
  user: PublicUser;
}

const CONFLICT_CODES: Record<string, [string, string]> = {
  users_phone_hash_key: ['PHONE_TAKEN', 'Phone number already registered'],
  users_email_key: ['EMAIL_TAKEN', 'Email already registered'],
  users_nic_hash_key: ['NIC_TAKEN', 'NIC already registered'],
};

@Injectable()
export class AuthService implements OnModuleInit {
  private dummyHash = '';

  constructor(
    private readonly users: UsersRepository,
    private readonly usersService: UsersService,
    private readonly otp: OtpService,
    private readonly crypto: CryptoService,
    private readonly tokens: TokenService,
    @Inject(CLOCK) private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly cfg: AppConfig,
  ) {}

  async onModuleInit(): Promise<void> {
    this.dummyHash = await this.crypto.hashPassword(
      randomBytes(16).toString('hex'),
    );
  }

  async requestPhoneOtp(phoneInput: string, language?: OtpLanguage) {
    const phone = normalizePhone(phoneInput);
    if (await this.users.findByPhoneHash(this.crypto.lookupHash(phone))) {
      throw new AppException(
        409,
        'PHONE_TAKEN',
        'Phone number already registered',
      );
    }
    const issued = await this.otp.issue(
      'phone_register',
      phone,
      null,
      language,
    );
    return otpResponse(issued, this.cfg.devOtpEcho);
  }

  async verifyPhoneOtp(
    phoneInput: string,
    code: string,
  ): Promise<{ phoneVerificationToken: string }> {
    const phone = normalizePhone(phoneInput);
    await this.otp.verify('phone_register', phone, code);
    return {
      phoneVerificationToken: await this.tokens.signPhoneVerified(
        this.crypto.lookupHash(phone),
      ),
    };
  }

  async register(input: RegisterInput): Promise<AuthResult> {
    const phone = normalizePhone(input.phone);
    const nic = normalizeNic(input.nic);
    const email = normalizeEmail(input.email);
    const phoneHash = this.crypto.lookupHash(phone);
    const nicHash = this.crypto.lookupHash(`nic:${nic}`);

    const tokenPhoneHash = await this.tokens.verifyPhoneVerified(
      input.phoneVerificationToken,
    );
    if (!tokenPhoneHash || !safeEqual(tokenPhoneHash, phoneHash)) {
      throw new AppException(
        400,
        'INVALID_VERIFICATION_TOKEN',
        'Phone verification is invalid or expired',
      );
    }

    const taken = await this.users.findConflicts({ phoneHash, email, nicHash });
    if (taken.phone)
      throw new AppException(409, ...CONFLICT_CODES.users_phone_hash_key);
    if (taken.email)
      throw new AppException(409, ...CONFLICT_CODES.users_email_key);
    if (taken.nic)
      throw new AppException(409, ...CONFLICT_CODES.users_nic_hash_key);

    let user: UserRecord;
    try {
      user = await this.users.create({
        fullName: input.fullName.trim(),
        age: input.age,
        phoneEncrypted: this.crypto.encryptPii(phone, 'phone'),
        phoneHash,
        nicEncrypted: this.crypto.encryptPii(nic, 'nic'),
        nicHash,
        email,
        passwordHash: await this.crypto.hashPassword(input.password),
        phoneVerifiedAt: this.clock.now(),
      });
    } catch (err) {
      const conflict =
        CONFLICT_CODES[(err as { constraint?: string }).constraint ?? ''];
      if (conflict && (err as { code?: string }).code === '23505')
        throw new AppException(409, ...conflict);
      throw err;
    }
    return this.startSession(user);
  }

  async login(identifier: string, password: string): Promise<AuthResult> {
    const user = await this.findByIdentifier(identifier);
    if (!user?.passwordHash) {
      await this.crypto.verifyPassword(password, this.dummyHash);
      throw this.invalidCredentials();
    }

    const now = this.clock.now();
    if (user.lockedUntil && user.lockedUntil.getTime() > now.getTime()) {
      throw new AppException(
        429,
        'ACCOUNT_LOCKED',
        'Too many failed attempts. Try again later',
      );
    }

    if (!(await this.crypto.verifyPassword(password, user.passwordHash))) {
      await this.users.recordLoginFailure(
        user.id,
        MAX_LOGIN_FAILURES,
        new Date(now.getTime() + LOCK_MINUTES * 60_000),
      );
      throw this.invalidCredentials();
    }
    return this.startSession(user);
  }

  /**
   * Sends a reset code to the phone or email the person typed. The answer
   * is the same whether or not the account exists.
   */
  async forgotPassword(identifier: string) {
    const user = await this.findByIdentifier(identifier);
    const target = user ? this.resetTarget(user, identifier) : null;
    const channel = identifier.includes('@') ? 'email' : 'sms';
    const generic = {
      channel,
      expiresInSeconds: OTP_TTL_SECONDS,
      resendAfterSeconds: OTP_RESEND_SECONDS,
    };
    if (!user || !target) return generic;
    try {
      const issued = await this.otp.issue(
        'password_reset',
        target,
        user.id,
        user.language,
      );
      return { channel, ...otpResponse(issued, this.cfg.devOtpEcho) };
    } catch (err) {
      // a cooldown would reveal that the account exists
      if (err instanceof AppException && err.code === 'OTP_COOLDOWN')
        return generic;
      throw err;
    }
  }

  /** A correct code sets the new password and signs every device out. */
  async resetPassword(
    identifier: string,
    code: string,
    newPassword: string,
  ): Promise<void> {
    const user = await this.findByIdentifier(identifier);
    const target = user ? this.resetTarget(user, identifier) : null;
    if (!user || !target)
      throw new AppException(400, 'INVALID_CODE', 'Invalid or expired code');
    await this.otp.verify('password_reset', target, code);
    await this.users.setPassword(
      user.id,
      await this.crypto.hashPassword(newPassword),
      this.clock.now(),
    );
  }

  private resetTarget(user: UserRecord, identifier: string): string | null {
    if (identifier.includes('@')) return user.email;
    return this.crypto.decryptPii(user.phoneEncrypted, 'phone');
  }

  async refresh(refreshToken: string): Promise<AuthResult> {
    const userId = await this.tokens.verifyRefresh(refreshToken);
    const user = userId ? await this.users.findById(userId) : null;
    if (!user) throw this.invalidRefresh();

    const presented = this.crypto.hashToken(refreshToken);
    if (
      !user.refreshTokenHash ||
      !safeEqual(user.refreshTokenHash, presented)
    ) {
      await this.users.setRefreshHash(user.id, null);
      throw this.invalidRefresh();
    }

    const pair = await this.tokens.issuePair(user.id);
    if (
      !(await this.users.rotateRefreshHash(
        user.id,
        presented,
        this.crypto.hashToken(pair.refreshToken),
      ))
    ) {
      await this.users.setRefreshHash(user.id, null);
      throw this.invalidRefresh();
    }
    return { user: this.usersService.toPublic(user), ...pair };
  }

  async logout(userId: string): Promise<void> {
    await this.users.setRefreshHash(userId, null);
  }

  private async startSession(user: UserRecord): Promise<AuthResult> {
    const pair = await this.tokens.issuePair(user.id);
    await this.users.recordLoginSuccess(
      user.id,
      this.crypto.hashToken(pair.refreshToken),
    );
    return { user: this.usersService.toPublic(user), ...pair };
  }

  private async findByIdentifier(
    identifier: string,
  ): Promise<UserRecord | null> {
    const id = identifier.trim();
    if (id.includes('@')) return this.users.findByEmail(normalizeEmail(id));
    const phone = tryNormalizePhone(id);
    return phone
      ? this.users.findByPhoneHash(this.crypto.lookupHash(phone))
      : null;
  }

  private invalidCredentials(): AppException {
    return new AppException(401, 'INVALID_CREDENTIALS', 'Invalid credentials');
  }

  private invalidRefresh(): AppException {
    return new AppException(
      401,
      'INVALID_REFRESH_TOKEN',
      'Invalid refresh token',
    );
  }
}
