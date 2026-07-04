import { Module } from '@nestjs/common';
import { StorageCleanupTasks } from './storage-cleanup-tasks.service';
import { StorageService } from './storage.service';

@Module({
  providers: [StorageService, StorageCleanupTasks],
  exports: [StorageService]
})
export class StorageModule {}
