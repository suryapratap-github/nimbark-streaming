import { Body, Controller, Delete, Get, Param, Patch, Post, Query, Req, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AuthenticatedRequest } from '../auth/types/authenticated-request';
import { ReportUserDto } from './dto/report-user.dto';
import { SubscribePlanDto } from './dto/subscribe-plan.dto';
import { UpdateLocationDto } from './dto/update-location.dto';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { UsersService } from './users.service';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('subscription-plans')
  subscriptionPlans() {
    return this.usersService.subscriptionPlans();
  }

  @Get('search')
  search(@Query('q') query = '') {
    return this.usersService.searchCreators(query);
  }

  @Get(':id')
  getProfile(@Param('id') id: string) {
    return this.usersService.getProfile(id);
  }

  @Patch(':id')
  @UseGuards(JwtAuthGuard)
  updateProfile(@Param('id') id: string, @Body() body: UpdateProfileDto, @Req() request: AuthenticatedRequest) {
    return this.usersService.updateProfile(id, body, request.user?.id);
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard)
  deleteProfile(@Param('id') id: string, @Req() request: AuthenticatedRequest) {
    return this.usersService.deleteProfile(id, request.user?.id);
  }

  @Patch(':id/location')
  @UseGuards(JwtAuthGuard)
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  updateLocation(@Param('id') id: string, @Body() body: UpdateLocationDto, @Req() request: AuthenticatedRequest) {
    return this.usersService.updateLocation(id, body, request.user?.id);
  }

  @Post(':id/followers')
  @UseGuards(JwtAuthGuard)
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  follow(@Param('id') followingId: string, @Req() request: AuthenticatedRequest) {
    return this.usersService.follow(request.user!.id, followingId);
  }

  @Post(':id/likes')
  @UseGuards(JwtAuthGuard)
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  likeCreator(@Param('id') creatorId: string, @Req() request: AuthenticatedRequest) {
    return this.usersService.toggleCreatorLike(request.user!.id, creatorId);
  }

  @Post(':id/shares')
  @UseGuards(JwtAuthGuard)
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  shareCreator(@Param('id') creatorId: string, @Req() request: AuthenticatedRequest) {
    return this.usersService.shareCreator(request.user!.id, creatorId);
  }

  @Post(':id/reports')
  @UseGuards(JwtAuthGuard)
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  report(@Param('id') subjectUserId: string, @Body() body: ReportUserDto, @Req() request: AuthenticatedRequest) {
    return this.usersService.reportUser(request.user!.id, subjectUserId, body.reason);
  }

  @Delete(':id/followers/me')
  @UseGuards(JwtAuthGuard)
  unfollow(@Param('id') followingId: string, @Req() request: AuthenticatedRequest) {
    return this.usersService.unfollow(request.user!.id, followingId);
  }

  @Get(':id/subscription')
  @UseGuards(JwtAuthGuard)
  subscription(@Param('id') id: string, @Req() request: AuthenticatedRequest) {
    return this.usersService.subscription(id, request.user?.id);
  }

  @Post(':id/subscriptions')
  @UseGuards(JwtAuthGuard)
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  subscribe(@Param('id') id: string, @Body() body: SubscribePlanDto, @Req() request: AuthenticatedRequest) {
    return this.usersService.subscribe(id, body.planId, request.user?.id);
  }

  @Delete(':id/subscription')
  @UseGuards(JwtAuthGuard)
  cancel(@Param('id') id: string, @Req() request: AuthenticatedRequest) {
    return this.usersService.cancel(id, request.user?.id);
  }

}
