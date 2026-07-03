import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { UsersService } from './users.service';

@Injectable()
export class SubscriptionTasks {
  private readonly logger = new Logger(SubscriptionTasks.name);

  constructor(private readonly usersService: UsersService) {}

  @Cron(CronExpression.EVERY_5_MINUTES)
  async handleExpiredSubscriptions() {
    this.logger.log('Checking for expired subscriptions...');

    try {
      const result = await this.usersService.downgradeExpiredSubscriptions();
      if (result.reverted > 0 || result.expiredUserIds > 0) {
        this.logger.log(`Downgraded ${result.reverted} CREATORs, expired ${result.expiredUserIds} subscriptions`);
      }
    } catch (error) {
      this.logger.error('Failed to process expired subscriptions', error instanceof Error ? error.message : String(error));
    }
  }
}
