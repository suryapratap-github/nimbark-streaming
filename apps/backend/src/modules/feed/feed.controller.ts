import { Body, Controller, Delete, Get, Param, Post, Query, Req, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AuthenticatedRequest } from '../auth/types/authenticated-request';
import { CreateCommentDto, PublishReelDto, PublishVideoDto, ReportDto } from './dto/feed.dto';
import { FeedService } from './feed.service';

@Controller('feed')
export class FeedController {
  constructor(private readonly feedService: FeedService) {}

  @Get('videos')
  videos() {
    return this.feedService.videos();
  }

  @Get('reels')
  reels() {
    return this.feedService.reels();
  }

  @Get('search')
  search(@Query('q') query = '') {
    return this.feedService.search(query);
  }

  @Get('creators/:id')
  creatorProfile(@Param('id') id: string) {
    return this.feedService.creatorProfile(id);
  }

  @Get(':type/:id/status')
  @UseGuards(JwtAuthGuard)
  status(@Param('type') type: 'video' | 'reel', @Param('id') id: string, @Req() request: AuthenticatedRequest) {
    return this.feedService.processingStatus(type, id, request.user);
  }

  @Get(':type/:id')
  item(@Param('type') type: 'video' | 'reel', @Param('id') id: string) {
    return this.feedService.item(type, id);
  }

  @Get(':type/:id/comments')
  comments(@Param('type') type: 'video' | 'reel', @Param('id') id: string) {
    return this.feedService.comments(type, id);
  }

  @Post(':type/:id/views')
  @UseGuards(JwtAuthGuard)
  view(@Param('type') type: 'video' | 'reel', @Param('id') id: string, @Req() request: AuthenticatedRequest) {
    return this.feedService.incrementView(type, id, request.user);
  }

  @Post(':type/:id/likes')
  @UseGuards(JwtAuthGuard)
  @Throttle({ default: { limit: 80, ttl: 60_000 } })
  like(@Param('type') type: 'video' | 'reel', @Param('id') id: string, @Req() request: AuthenticatedRequest) {
    return this.feedService.toggleLike(type, id, request.user);
  }

  @Post(':type/:id/dislikes')
  @UseGuards(JwtAuthGuard)
  @Throttle({ default: { limit: 80, ttl: 60_000 } })
  dislike(@Param('type') type: 'video' | 'reel', @Param('id') id: string, @Req() request: AuthenticatedRequest) {
    return this.feedService.toggleDislike(type, id, request.user);
  }

  @Post(':type/:id/shares')
  @UseGuards(JwtAuthGuard)
  @Throttle({ default: { limit: 40, ttl: 60_000 } })
  share(@Param('type') type: 'video' | 'reel', @Param('id') id: string, @Req() request: AuthenticatedRequest) {
    return this.feedService.share(type, id, request.user);
  }

  @Post(':type/:id/comments')
  @UseGuards(JwtAuthGuard)
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  createComment(
    @Param('type') type: 'video' | 'reel',
    @Param('id') id: string,
    @Body() body: CreateCommentDto,
    @Req() request: AuthenticatedRequest
  ) {
    return this.feedService.createComment(type, id, body.body, request.user);
  }

  @Delete(':type/:id/comments/:commentId')
  @UseGuards(JwtAuthGuard)
  deleteComment(
    @Param('type') type: 'video' | 'reel',
    @Param('id') id: string,
    @Param('commentId') commentId: string,
    @Req() request: AuthenticatedRequest
  ) {
    return this.feedService.deleteComment(type, id, commentId, request.user);
  }

  @Post(':type/:id/comments/:commentId/reports')
  @UseGuards(JwtAuthGuard)
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  reportComment(
    @Param('type') type: 'video' | 'reel',
    @Param('id') id: string,
    @Param('commentId') commentId: string,
    @Body() body: ReportDto,
    @Req() request: AuthenticatedRequest
  ) {
    return this.feedService.reportComment(type, id, commentId, body.reason, request.user);
  }

  @Post(':type/:id/reports')
  @UseGuards(JwtAuthGuard)
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  report(
    @Param('type') type: 'video' | 'reel',
    @Param('id') id: string,
    @Body() body: ReportDto,
    @Req() request: AuthenticatedRequest
  ) {
    return this.feedService.report(type, id, body.reason, request.user);
  }

  @Delete(':type/:id')
  @UseGuards(JwtAuthGuard)
  deletePost(@Param('type') type: 'video' | 'reel', @Param('id') id: string, @Req() request: AuthenticatedRequest) {
    return this.feedService.deletePost(type, id, request.user);
  }

  @Post('videos')
  @UseGuards(JwtAuthGuard)
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  publishVideo(
    @Body() body: PublishVideoDto,
    @Req() request: AuthenticatedRequest
  ) {
    return this.feedService.publishVideo(body, request.user);
  }

  @Post('reels')
  @UseGuards(JwtAuthGuard)
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  publishReel(
    @Body() body: PublishReelDto,
    @Req() request: AuthenticatedRequest
  ) {
    return this.feedService.publishReel(body, request.user);
  }
}
