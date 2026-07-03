import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Cron, CronExpression } from '@nestjs/schedule';
import { StorageService } from './storage.service';

@Injectable()
export class StorageCleanupTasks {
  private readonly logger = new Logger(StorageCleanupTasks.name);

  constructor(
    private readonly config: ConfigService,
    private readonly storage: StorageService
  ) {}

  @Cron(CronExpression.EVERY_DAY_AT_3AM)
  async cleanupOrphanedMedia() {
    const deleteOrphans = this.config.get<string>('MEDIA_CLEANUP_DELETE_ORPHANS') === 'true';

    try {
      const result = await this.storage.cleanupOrphanedLocalMedia({ dryRun: !deleteOrphans });

      if (result.candidates > 0 || result.deleted > 0) {
        this.logger.log(
          `Media cleanup completed: candidates=${result.candidates}, deleted=${result.deleted}, dryRun=${result.dryRun}`
        );
      }
    } catch (error) {
      this.logger.error('Media cleanup failed', error instanceof Error ? error.message : String(error));
    }
  }
}
