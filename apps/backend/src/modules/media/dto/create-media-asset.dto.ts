import { IsEnum, IsInt, IsOptional, IsString, IsUrl, Min } from 'class-validator';
import { MediaType } from '@prisma/client';

export class CreateMediaAssetDto {
  @IsString()
  ownerId!: string;

  @IsEnum(MediaType)
  type!: MediaType;

  @IsString()
  bucket!: string;

  @IsString()
  objectKey!: string;

  @IsOptional()
  @IsUrl()
  publicUrl?: string;

  @IsString()
  contentType!: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  sizeBytes?: number;
}
