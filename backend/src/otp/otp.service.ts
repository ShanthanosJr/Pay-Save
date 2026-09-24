import { Inject, Injectable } from '@nestjs/common';
import { randomInt } from 'node:crypto';
import { CLOCK } from '../common/clock/clock';
import type { Clock } from '../common/clock/clock';
import { CryptoService } from '../common/crypto/crypto.service';
import { safeEqual } from '../common/crypto/hash';
import { AppException } from '../common/errors/app.exception';
import { OtpRepository } from './otp.repository';
import { OTP_SENDER, OtpPurpose } from './otp-sender';
import type { OtpSender } from './otp-sender';

export const OTP_TTL_SECONDS = 300;
export const OTP_RESEND_SECONDS = 30;
export const OTP_MAX_ATTEMPTS = 5;

export interface OtpIssued {
  code: string;
  expiresInSeconds: number;
  resendAfterSeconds: number;
}

export function otpResponse(issued: OtpIssued, echo: boolean) {
  return {
    expiresInSeconds: issued.expiresInSeconds,
    resendAfterSeconds: issued.resendAfterSeconds,
    ...(echo ? { devCode: issued.code } : {}),
  };
}

@Injectable()
export class OtpService {
  constructor(
    private readonly repo: OtpRepository,
    @Inject(OTP_SENDER) private readonly sender: OtpSender,
    private readonly crypto: CryptoService,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  async issue(
    purpose: OtpPurpose,
    target: string,
    userId: string | null = null,
  ): Promise<OtpIssued> {
    const now = this.clock.now();
    const targetHash = this.crypto.lookupHash(target);

    const latest = await this.repo.findLatest(purpose, targetHash);
    if (latest) {
      const waitMs =
        latest.createdAt.getTime() + OTP_RESEND_SECONDS * 1000 - now.getTime();
      if (waitMs > 0) {
        const retryAfterSeconds = Math.ceil(waitMs / 1000);
        throw new AppException(
          429,
          'OTP_COOLDOWN',
          'Please wait before requesting another code',
          {
            retryAfterSeconds,
          },
        );
      }
    }

    const code = String(randomInt(0, 1_000_000)).padStart(6, '0');
    await this.repo.invalidateActive(purpose, targetHash, now);
    await this.repo.insert({
      purpose,
      targetHash,
      userId,
      codeHash: this.codeHash(purpose, targetHash, code),
      expiresAt: new Date(now.getTime() + OTP_TTL_SECONDS * 1000),
      createdAt: now,
    });
    await this.sender.send({ purpose, target, code });

    return {
      code,
      expiresInSeconds: OTP_TTL_SECONDS,
      resendAfterSeconds: OTP_RESEND_SECONDS,
    };
  }

  async verify(
    purpose: OtpPurpose,
    target: string,
    code: string,
  ): Promise<void> {
    const now = this.clock.now();
    const targetHash = this.crypto.lookupHash(target);
    const challenge = await this.repo.findLatest(purpose, targetHash);

    if (!challenge || challenge.consumedAt) throw this.invalid();
    if (challenge.attempts >= OTP_MAX_ATTEMPTS) throw this.locked();
    if (challenge.expiresAt.getTime() <= now.getTime()) throw this.invalid();

    if (
      !safeEqual(challenge.codeHash, this.codeHash(purpose, targetHash, code))
    ) {
      const attempts = await this.repo.incrementAttempts(challenge.id);
      throw attempts >= OTP_MAX_ATTEMPTS ? this.locked() : this.invalid();
    }
    if (!(await this.repo.consume(challenge.id, now))) throw this.invalid();
  }

  private codeHash(
    purpose: OtpPurpose,
    targetHash: string,
    code: string,
  ): string {
    return this.crypto.lookupHash(`otp:${purpose}:${targetHash}:${code}`);
  }

  private invalid(): AppException {
    return new AppException(400, 'INVALID_CODE', 'Invalid or expired code');
  }

  private locked(): AppException {
    return new AppException(
      429,
      'OTP_LOCKED',
      'Too many attempts. Request a new code',
    );
  }
}
