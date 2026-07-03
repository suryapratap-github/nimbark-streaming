import { Body, Controller, Delete, Get, Param, Patch, Post, Query, Req, UseGuards } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { Throttle } from '@nestjs/throttler';
import { Roles } from '../auth/decorators/roles.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { AuthenticatedRequest } from '../auth/types/authenticated-request';
import {
  ReportActionDto,
  StorageCleanupDto,
  UpdateFeedItemDto,
  UpdateReportStatusDto,
  UpdateStorageSettingsDto,
  UpdateUserAccessDto
} from './dto/admin-actions.dto';
import { CreateAdminUserDto } from './dto/create-admin-user.dto';
import { CreateSubscriptionPlanDto } from './dto/create-subscription-plan.dto';
import { UpdateAdminUserDto } from './dto/update-admin-user.dto';
import { UpdateSubscriptionPlanDto } from './dto/update-subscription-plan.dto';
import { AdminService } from './admin.service';

@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Get('dashboard')
  dashboard() {
    return this.adminService.dashboard();
  }

  @Get('users')
  users() {
    return this.adminService.users();
  }

  @Post('users')
  createUser(@Body() body: CreateAdminUserDto) {
    return this.adminService.createUser(body);
  }

  @Patch('users/:id')
  updateUser(@Param('id') id: string, @Body() body: UpdateAdminUserDto) {
    return this.adminService.updateUser(id, body);
  }

  @Get('reports')
  reports(@Query('status') status = 'ALL') {
    return this.adminService.reports(status);
  }

  @Get('payment-events')
  paymentEvents() {
    return this.adminService.paymentEvents();
  }

  @Patch('reports/:id')
  updateReportStatus(@Param('id') id: string, @Body() body: UpdateReportStatusDto, @Req() request: AuthenticatedRequest) {
    return this.adminService.updateReportStatus(id, body.status, request.user?.id);
  }

  @Post('reports/:id/actions')
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  actionReport(
    @Param('id') id: string,
    @Body() body: ReportActionDto,
    @Req() request: AuthenticatedRequest
  ) {
    return this.adminService.actionReport(id, body.action, request.user?.id);
  }

  @Get('feed-items')
  feedItems(@Query('status') status = 'ACTIVE') {
    return this.adminService.feedItems(status);
  }

  @Patch('feed-items/:type/:id')
  updateFeedItem(
    @Param('type') type: 'VIDEO' | 'REEL',
    @Param('id') id: string,
    @Body() body: UpdateFeedItemDto,
    @Req() request: AuthenticatedRequest
  ) {
    return this.adminService.updateFeedItem(type, id, body, request.user?.id);
  }

  @Get('live-rooms')
  liveRooms() {
    return this.adminService.liveRooms();
  }

  @Get('location-insights')
  locationInsights() {
    return this.adminService.locationInsights();
  }

  @Get('storage-settings')
  storageSettings() {
    return this.adminService.storageSettings();
  }

  @Get('storage-health')
  storageHealth() {
    return this.adminService.storageHealth();
  }

  @Post('storage-cleanup')
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  storageCleanup(@Body() body: StorageCleanupDto) {
    return this.adminService.cleanupOrphanedMedia(body.dryRun ?? true);
  }

  @Get('media-processing-jobs')
  mediaProcessingJobs() {
    return this.adminService.mediaProcessingJobs();
  }

  @Get('audit-logs')
  auditLogs(@Query('action') action?: string, @Query('adminId') adminId?: string, @Query('target') target?: string) {
    return this.adminService.auditLogs({ action, adminId, target });
  }

  @Patch('storage-settings')
  updateStorageSettings(@Body() body: UpdateStorageSettingsDto) {
    return this.adminService.updateStorageSettings(body);
  }

  @Get('subscription-plans')
  subscriptionPlans() {
    return this.adminService.subscriptionPlans();
  }

  @Post('subscription-plans')
  createSubscriptionPlan(@Body() body: CreateSubscriptionPlanDto) {
    return this.adminService.createSubscriptionPlan(body);
  }

  @Patch('subscription-plans/:id')
  updateSubscriptionPlan(@Param('id') id: string, @Body() body: UpdateSubscriptionPlanDto) {
    return this.adminService.updateSubscriptionPlan(id, body);
  }

  @Patch('users/:id/access')
  updateUserAccess(
    @Param('id') id: string,
    @Body() body: UpdateUserAccessDto,
    @Req() request: AuthenticatedRequest
  ) {
    return this.adminService.updateUserAccess(id, body.isActive, request.user?.id);
  }

  @Delete('users/:id/subscription')
  cancelUserSubscription(@Param('id') id: string, @Req() request: AuthenticatedRequest) {
    return this.adminService.cancelUserSubscription(id, request.user?.id);
  }

  @Delete('users/:id')
  deleteUser(@Param('id') id: string, @Req() request: AuthenticatedRequest) {
    return this.adminService.deleteUser(id, request.user?.id);
  }
}
