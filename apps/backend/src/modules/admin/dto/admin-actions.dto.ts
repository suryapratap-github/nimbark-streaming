import { IsBoolean, IsEnum, IsIn, IsOptional, IsString, MaxLength } from 'class-validator';
import { PublishStatus, ReportStatus, StorageProvider } from '@prisma/client';

export class UpdateReportStatusDto {
  @IsEnum(ReportStatus)
  status!: ReportStatus;
}

export class ReportActionDto {
  @IsIn(['MARK_REVIEWING', 'DISMISS', 'BLOCK_CONTENT', 'BLOCK_USER'])
  action!: 'MARK_REVIEWING' | 'DISMISS' | 'BLOCK_CONTENT' | 'BLOCK_USER';
}

export class UpdateFeedItemDto {
  @IsOptional()
  @IsEnum(PublishStatus)
  status?: PublishStatus;

  @IsOptional()
  @IsBoolean()
  commentsEnabled?: boolean;
}

export class StorageCleanupDto {
  @IsOptional()
  @IsBoolean()
  dryRun?: boolean;
}

export class UpdateStorageSettingsDto {
  @IsOptional()
  @IsEnum(StorageProvider)
  provider?: StorageProvider;

  @IsOptional()
  @IsString()
  @MaxLength(240)
  localBasePath?: string;

  @IsOptional()
  @IsString()
  @MaxLength(240)
  localPublicUrl?: string;

  @IsOptional()
  @IsBoolean()
  videoCompressionEnabled?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  r2Bucket?: string;

  @IsOptional()
  @IsString()
  @MaxLength(240)
  r2Endpoint?: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  r2Region?: string;

  @IsOptional()
  @IsString()
  @MaxLength(160)
  r2AccessKeyId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(240)
  r2SecretKey?: string;

  @IsOptional()
  @IsString()
  @MaxLength(240)
  r2PublicUrl?: string;
}

export class UpdateUserAccessDto {
  @IsBoolean()
  isActive!: boolean;
}
