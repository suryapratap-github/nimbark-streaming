import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { MediaProcessingModule } from '../media-processing/media-processing.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { StorageModule } from '../storage/storage.module';
import { FeedController } from './feed.controller';
import { FeedService } from './feed.service';

@Module({
  imports: [AuthModule, NotificationsModule, MediaProcessingModule, StorageModule],
  controllers: [FeedController],
  providers: [FeedService]
})
export class FeedModule {}
