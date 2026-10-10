import { Transform, Type } from 'class-transformer';
import {
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Max,
  Min,
  IsBoolean,
  IsIn,
  MaxLength,
  ValidateIf,
} from 'class-validator';

const trim = ({ value }: { value: unknown }): unknown =>
  typeof value === 'string' ? value.trim() : value;

export class SearchQueryDto {
  @Transform(trim)
  @IsString()
  @Length(1, 60)
  q!: string;
}

export class OpenChatDto {
  @IsUUID()
  userId!: string;
}

export class SendMessageDto {
  /** Device-generated UUID v4; a retry must reuse it. */
  @IsUUID('4')
  clientMessageId!: string;

  @Transform(trim)
  @IsString()
  @Length(1, 2000)
  body!: string;
}

export class MessagesQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  before?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  after?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;
}

/** Multipart fields arrive as strings. */
export class SendMediaDto {
  @IsUUID('4')
  clientMessageId!: string;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(500)
  caption?: string;
}

export class ReactionDto {
  /** null removes my reaction. */
  @ValidateIf((o: ReactionDto) => o.emoji !== null)
  @IsIn(['👍', '❤️', '😂', '😮', '😢', '🙏'])
  emoji!: string | null;
}

export class StarDto {
  @IsBoolean()
  starred!: boolean;
}

export class ChatFlagsDto {
  @IsOptional()
  @IsBoolean()
  pinned?: boolean;

  @IsOptional()
  @IsBoolean()
  favourite?: boolean;
}
