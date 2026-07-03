import { IsNotEmpty, IsString, MaxLength } from 'class-validator';

export class CreateLiveRoomDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  title!: string;
}
