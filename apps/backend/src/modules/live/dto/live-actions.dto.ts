import { IsBoolean, IsIn, IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateLiveCommentDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(250)
  body!: string;
}

export class CreateLiveReactionDto {
  @IsString()
  @IsIn(['❤️', '🔥', '👏', '😂'])
  emoji!: string;
}

export class ReportLiveRoomDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  reason!: string;
}

export class UpdateLiveSettingsDto {
  @IsOptional()
  @IsBoolean()
  commentsOn?: boolean;

  @IsOptional()
  @IsBoolean()
  reactionsOn?: boolean;
}

export class BlockViewerDto {
  @IsString()
  @IsNotEmpty()
  userId!: string;
}

export class CreateLiveTokenDto {
  @IsString()
  @IsNotEmpty()
  roomId!: string;
}
