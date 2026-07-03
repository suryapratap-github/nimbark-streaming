import { IsBoolean, IsInt, IsOptional, IsString, MaxLength, Min } from 'class-validator';

export class CreateSubscriptionPlanDto {
  @IsString()
  @MaxLength(80)
  name!: string;

  @IsOptional()
  @IsString()
  @MaxLength(240)
  description?: string;

  @IsInt()
  @Min(0)
  priceCents!: number;

  @IsOptional()
  @IsString()
  @MaxLength(3)
  currency?: string;

  @IsInt()
  @Min(1)
  durationDays!: number;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  revenueCatOfferingId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  revenueCatPackageId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  revenueCatEntitlementId?: string;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
