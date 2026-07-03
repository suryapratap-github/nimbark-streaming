import { Body, Controller, Get, Param, Patch, Post, Req, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AuthenticatedRequest } from '../auth/types/authenticated-request';
import { RegisterDeviceTokenDto } from './dto/register-device-token.dto';
import { NotificationsService } from './notifications.service';

@Controller('notifications')
@UseGuards(JwtAuthGuard)
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Get()
  list(@Req() request: AuthenticatedRequest) {
    return this.notificationsService.list(request.user!.id);
  }

  @Get('unread-count')
  unreadCount(@Req() request: AuthenticatedRequest) {
    return this.notificationsService.unreadCount(request.user!.id);
  }

  @Patch('read-all')
  markAllRead(@Req() request: AuthenticatedRequest) {
    return this.notificationsService.markAllRead(request.user!.id);
  }

  @Patch(':id/read')
  markRead(@Param('id') id: string, @Req() request: AuthenticatedRequest) {
    return this.notificationsService.markRead(request.user!.id, id);
  }

  @Post('device-tokens')
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  registerDeviceToken(
    @Body() body: RegisterDeviceTokenDto,
    @Req() request: AuthenticatedRequest
  ) {
    return this.notificationsService.registerDeviceToken({
      userId: request.user!.id,
      token: body.token,
      platform: body.platform
    });
  }
}
