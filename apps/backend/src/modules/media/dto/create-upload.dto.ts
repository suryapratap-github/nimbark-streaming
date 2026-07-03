import { IsNotEmpty, IsString, MaxLength } from 'class-validator';

export class CreateUploadDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(240)
  fileName!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  contentType!: string;
}
