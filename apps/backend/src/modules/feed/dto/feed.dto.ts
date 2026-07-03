import { Type } from 'class-transformer';
import { IsBoolean, IsIn, IsInt, IsNotEmpty, IsOptional, IsString, MaxLength, Min, ValidateNested } from 'class-validator';

class PublishMediaDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  objectKey!: string;

  @IsOptional()
  @IsIn(['LOCAL', 'R2'])
  provider?: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  publicUrl?: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  contentType!: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  sizeBytes?: number;
}

export class PublishVideoDto extends PublishMediaDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(140)
  title!: string;

  @IsOptional()
  @IsString()
  @MaxLength(800)
  description?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  durationMs?: number;

  @IsOptional()
  @IsBoolean()
  commentsEnabled?: boolean;

  @IsOptional()
  @ValidateNested()
  @Type(() => PublishMediaDto)
  thumbnail?: PublishMediaDto;
}

export class PublishReelDto extends PublishMediaDto {
  @IsOptional()
  @IsString()
  @MaxLength(220)
  caption?: string;

  @IsInt()
  @Min(0)
  durationMs!: number;

  @IsOptional()
  @IsBoolean()
  commentsEnabled?: boolean;

  @IsOptional()
  @ValidateNested()
  @Type(() => PublishMediaDto)
  thumbnail?: PublishMediaDto;
}

export class CreateCommentDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(250)
  body!: string;
}

export class ReportDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  reason!: string;
}
