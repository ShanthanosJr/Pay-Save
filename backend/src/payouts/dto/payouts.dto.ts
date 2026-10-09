import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
} from 'class-validator';
import { PAYOUT_KINDS } from '../payout-details';
import type { PayoutKind } from '../payout-details';

/** Per-kind rules live in toPayoutDetails(); this only bounds the shape. */
export class AddPayoutMethodDto {
  @IsIn(PAYOUT_KINDS)
  kind!: PayoutKind;

  @IsOptional() @IsString() @MaxLength(80) bankName?: string;
  @IsOptional() @IsString() @MaxLength(80) branch?: string;
  @IsOptional() @IsString() @MaxLength(100) accountName?: string;
  @IsOptional() @IsString() @MaxLength(40) accountNumber?: string;
  @IsOptional() @IsString() @MaxLength(40) provider?: string;
  @IsOptional() @IsString() @MaxLength(32) number?: string;
  @IsOptional() @IsString() @MaxLength(100) merchantName?: string;
  @IsOptional() @IsString() @MaxLength(60) reference?: string;
  @IsOptional() @IsString() @MaxLength(160) note?: string;

  /** Make this the method shared automatically with new circles. */
  @IsOptional() @IsBoolean() makeDefault?: boolean;
}

export class SharePayoutMethodsDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(5)
  @IsUUID('all', { each: true })
  methodIds!: string[];

  @IsUUID()
  preferredId!: string;
}
