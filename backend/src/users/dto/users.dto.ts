import { IsIn, IsOptional, IsString, Matches } from 'class-validator';

export class UpdateMeDto {
  @IsOptional()
  @IsIn(['en', 'si', 'ta'])
  language?: 'en' | 'si' | 'ta';
}

export class VerifyEmailDto {
  @IsString()
  @Matches(/^\d{6}$/)
  code!: string;
}
