import { Transform } from 'class-transformer';
import {
  IsEmail,
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

export class OtpRequestDto {
  @IsString()
  @MaxLength(32)
  phone!: string;
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

  @IsString()
  @Length(8, 72)
  @Matches(/[A-Za-z]/, { message: 'password must contain a letter' })
  @Matches(/\d/, { message: 'password must contain a digit' })
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
