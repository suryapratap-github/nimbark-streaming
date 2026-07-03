import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { MediaProcessingModule } from '../media-processing/media-processing.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { StorageModule } from '../storage/storage.module';
import { LiveController } from './live.controller';
import { LiveService } from './live.service';

@Module({
  imports: [AuthModule, NotificationsModule, StorageModule, MediaProcessingModule],
  controllers: [LiveController],
  providers: [LiveService]
})
export class LiveModule {}
