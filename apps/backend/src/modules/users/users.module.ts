import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';
import { AuthModule } from '../auth/auth.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';
import { SubscriptionTasks } from './subscription-tasks.service';

@Module({
  imports: [AuthModule, NotificationsModule, ScheduleModule.forRoot()],
  controllers: [UsersController],
  providers: [UsersService, SubscriptionTasks],
  exports: [UsersService]
})
export class UsersModule {}
