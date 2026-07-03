import { IsNotEmpty, IsString, MaxLength } from 'class-validator';

export class ReportUserDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  reason!: string;
}
