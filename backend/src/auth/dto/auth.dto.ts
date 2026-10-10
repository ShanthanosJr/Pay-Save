import { applyDecorators } from '@nestjs/common';
import { Transform } from 'class-transformer';
import {
  IsEmail,
  IsIn,
  IsOptional,
  IsInt,
  IsString,
  Length,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

const trim = ({ value }: { value: unknown }): unknown =>
  typeof value === 'string' ? value.trim() : value;

const LANGUAGES = ['en', 'si', 'ta'] as const;

/** One rule for every place a password is chosen. */
export const PasswordRules = () =>
  applyDecorators(
    IsString(),
    Length(8, 72),
    Matches(/[A-Za-z]/, { message: 'password must contain a letter' }),
    Matches(/\d/, { message: 'password must contain a digit' }),
  );

export class OtpRequestDto {
  @IsString()
  @MaxLength(32)
  phone!: string;

  /** Language of the SMS; the account does not exist yet. */
  @IsOptional()
  @IsIn(LANGUAGES)
  language?: (typeof LANGUAGES)[number];
}

export class ForgotPasswordDto {
  @IsString()
  @MaxLength(254)
  identifier!: string;
}

export class ResetPasswordDto {
  @IsString()
  @MaxLength(254)
  identifier!: string;

  @IsString()
  @Matches(/^\d{6}$/)
  code!: string;

  @PasswordRules()
  newPassword!: string;
}

export class OtpVerifyDto {
  @IsString()
  @MaxLength(32)
  phone!: string;

  @IsString()
  @Matches(/^\d{6}$/)
  code!: string;
}

export class RegisterDto {
  @Transform(trim)
  @IsString()
  @Length(2, 80)
  fullName!: string;

  @IsInt()
  @Min(18)
  @Max(120)
  age!: number;

  @IsString()
  @MaxLength(20)
  nic!: string;

  @IsString()
  @MaxLength(32)
  phone!: string;

  @Transform(trim)
  @IsEmail()
  @MaxLength(254)
  email!: string;

  @PasswordRules()
  password!: string;

  @IsString()
  @MaxLength(2048)
  phoneVerificationToken!: string;
}

export class LoginDto {
  @IsString()
  @MaxLength(254)
  identifier!: string;

  @IsString()
  @MaxLength(200)
  password!: string;
}

export class RefreshDto {
  @IsString()
  @MaxLength(2048)
  refreshToken!: string;
}
