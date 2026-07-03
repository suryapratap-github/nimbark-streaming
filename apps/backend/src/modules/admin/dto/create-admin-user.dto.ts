import { IsEmail, IsEnum, IsNotEmpty, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';
import { UserRole } from '@prisma/client';

export class CreateAdminUserDto {
  @IsEmail()
  email!: string;

  @IsString()
  @MinLength(8)
  @MaxLength(72)
  password!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(60)
  displayName!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(30)
  username!: string;

  @IsOptional()
  @IsEnum(UserRole)
  role?: UserRole;
}
