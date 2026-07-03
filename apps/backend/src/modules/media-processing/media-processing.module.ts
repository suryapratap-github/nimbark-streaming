import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';
import { StorageModule } from '../storage/storage.module';
import { MediaProcessingService } from './media-processing.service';

@Module({
  imports: [ScheduleModule.forRoot(), StorageModule],
  providers: [MediaProcessingService],
  exports: [MediaProcessingService]
})
export class MediaProcessingModule {}
