import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';
import { StorageCleanupTasks } from './storage-cleanup-tasks.service';
import { StorageService } from './storage.service';

@Module({
  imports: [ScheduleModule.forRoot()],
  providers: [StorageService, StorageCleanupTasks],
  exports: [StorageService]
})
export class StorageModule {}
