import { IsString } from 'class-validator';

export class SubscribePlanDto {
  @IsString()
  planId!: string;
}
