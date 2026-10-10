import { Transform } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { INTERVALS } from '../domain/schedule';
import type { CircleInterval } from '../domain/schedule';

export const TURN_RULES = ['fixed', 'lottery', 'need_based'] as const;
export type TurnRule = (typeof TURN_RULES)[number];

export const COLLECTION_MODES = [
  'direct_to_recipient',
  'via_organizer',
] as const;

const trim = ({ value }: { value: unknown }): unknown =>
  typeof value === 'string' ? value.trim() : value;

export class CreateCircleDto {
  @Transform(trim)
  @IsString()
  @Length(2, 60)
  name!: string;

  @IsInt()
  @Min(100)
  @Max(100_000_000)
  contributionMinor!: number;

  @IsIn(INTERVALS)
  interval!: CircleInterval;

  @IsIn(TURN_RULES)
  turnRule!: TurnRule;

  @IsInt()
  @Min(2)
  @Max(60)
  plannedCycles!: number;

  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  firstDueDate!: string;

  @IsOptional()
  @IsIn(COLLECTION_MODES)
  collectionMode?: (typeof COLLECTION_MODES)[number];
}

export class CircleSettingsDto {
  @IsOptional()
  @IsIn(COLLECTION_MODES)
  collectionMode?: (typeof COLLECTION_MODES)[number];

  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  firstDueDate?: string;
}

export class InvitePalsDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(59)
  @IsUUID('all', { each: true })
  userIds!: string[];

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(200)
  message?: string;
}

export class AcceptInvitationDto {
  /** Methods to share with the circle; the default one is used if omitted. */
  @IsOptional()
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(5)
  @IsUUID('all', { each: true })
  methodIds?: string[];

  @IsOptional()
  @IsUUID()
  preferredId?: string;
}

export class JoinCircleDto {
  @IsString()
  @MaxLength(32)
  code!: string;
}

export class StartCircleDto {
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(60)
  @IsString({ each: true })
  @MaxLength(64, { each: true })
  order?: string[];
}

export class CloseCycleDto {
  @IsInt()
  @Min(0)
  @Max(60)
  acknowledgeUnpaid!: number;
}

export class LedgerQueryDto {
  @IsOptional()
  @IsIn(['mine', 'all'])
  scope?: 'mine' | 'all';
}

export class RemoveMemberDto {
  /** Required once the circle is running; members see it in the record. */
  @IsOptional()
  @Transform(trim)
  @IsString()
  @Length(3, 200)
  reason?: string;
}
