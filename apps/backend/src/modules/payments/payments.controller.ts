import { Body, Controller, Get, Headers, Post, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { PaymentsService } from './payments.service';

@Controller('payments')
export class PaymentsController {
  constructor(private readonly paymentsService: PaymentsService) {}

  @Get('revenuecat/config')
  @UseGuards(JwtAuthGuard)
  revenueCatConfig() {
    return this.paymentsService.revenueCatConfig();
  }

  @Post('revenuecat/webhook')
  @Throttle({ default: { limit: 120, ttl: 60_000 } })
  revenueCatWebhook(@Body() body: unknown, @Headers('authorization') authorization?: string) {
    return this.paymentsService.handleRevenueCatWebhook(body, authorization);
  }
}
