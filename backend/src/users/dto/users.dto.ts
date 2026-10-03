import { Transform } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Length,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

const trim = ({ value }: { value: unknown }): unknown =>
  typeof value === 'string' ? value.trim() : value;
const handle = ({ value }: { value: unknown }): unknown =>
  typeof value === 'string'
    ? value.trim().replace(/^@/, '').toLowerCase()
    : value;

/** Every field optional; email and password are deliberately not editable here. */
export class UpdateMeDto {
  @IsOptional()
  @IsIn(['en', 'si', 'ta'])
  language?: 'en' | 'si' | 'ta';

  @IsOptional()
  @Transform(trim)
  @IsString()
  @Length(2, 80)
  fullName?: string;

  @IsOptional()
  @IsInt()
  @Min(18)
  @Max(120)
  age?: number;

  /** '' clears it. */
  @IsOptional()
  @Transform(handle)
  @IsString()
  @Matches(/^$|^[a-z0-9._]{3,30}$/, {
    message:
      'username must be 3-30 characters: letters, numbers, dots or underscores',
  })
  username?: string;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(160)
  bio?: string;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(60)
  city?: string;
}

export class ChangePhoneDto {
  @IsString()
  @MaxLength(32)
  phone!: string;

  @IsString()
  @MaxLength(2048)
  phoneVerificationToken!: string;
}

export class VerifyEmailDto {
  @IsString()
  @Matches(/^\d{6}$/)
  code!: string;
}
