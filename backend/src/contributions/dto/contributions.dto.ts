import { Transform } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsISO8601,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  MaxLength,
  Min,
} from 'class-validator';
import { PAYMENT_METHODS } from '../../ledger/ledger.types';
import type { PaymentMethod } from '../../ledger/ledger.types';

const trim = ({ value }: { value: unknown }): unknown =>
  typeof value === 'string' ? value.trim() : value;

export class RecordContributionDto {
  @IsInt()
  @Min(1)
  cycleNumber!: number;

  @IsIn(PAYMENT_METHODS)
  method!: PaymentMethod;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(40)
  provider?: string;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(64)
  receiptReference?: string;

  @IsUUID('4')
  clientEntryId!: string;

  @IsOptional()
  @IsISO8601({ strict: true })
  deviceCreatedAt?: string;

  @IsOptional()
  @IsUUID('all')
  subjectUserId?: string;
}

export class RejectContributionDto {
  @Transform(trim)
  @IsString()
  @Length(2, 200)
  reason!: string;
}
