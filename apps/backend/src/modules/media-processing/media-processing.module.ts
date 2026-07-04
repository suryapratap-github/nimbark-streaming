import { Module } from '@nestjs/common';
import { StorageModule } from '../storage/storage.module';
import { MediaProcessingService } from './media-processing.service';

@Module({
  imports: [StorageModule],
  providers: [MediaProcessingService],
  exports: [MediaProcessingService]
})
export class MediaProcessingModule {}
