import { Body, Controller, Delete, Get, Param, Patch, Post, Query, Req, UseGuards } from '@nestjs/common';
import { LiveRoomStatus } from '@prisma/client';
import { Throttle } from '@nestjs/throttler';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AuthenticatedRequest } from '../auth/types/authenticated-request';
import { CreateLiveRoomDto } from './dto/create-live-room.dto';
import {
  BlockViewerDto,
  CreateLiveCommentDto,
  CreateLiveReactionDto,
  CreateLiveTokenDto,
  ReportLiveRoomDto,
  UpdateLiveSettingsDto
} from './dto/live-actions.dto';
import { LiveService } from './live.service';

@Controller('live')
export class LiveController {
  constructor(private readonly liveService: LiveService) {}

  @Get('rooms')
  rooms(@Query('status') status?: LiveRoomStatus) {
    return this.liveService.rooms(status);
  }

  @Post('rooms')
  @UseGuards(JwtAuthGuard)
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  createRoom(@Body() body: CreateLiveRoomDto, @Req() request: AuthenticatedRequest) {
    return this.liveService.createRoom(body, request.user);
  }

  @Post('rooms/:roomId/start')
  @UseGuards(JwtAuthGuard)
  startRoom(@Param('roomId') roomId: string, @Req() request: AuthenticatedRequest) {
    return this.liveService.startRoom(roomId, request.user);
  }

  @Post('rooms/:roomId/end')
  @UseGuards(JwtAuthGuard)
  endRoom(@Param('roomId') roomId: string, @Req() request: AuthenticatedRequest) {
    return this.liveService.endRoom(roomId, request.user);
  }

  @Post('rooms/:roomId/recording/start')
  @UseGuards(JwtAuthGuard)
  startRecording(@Param('roomId') roomId: string, @Req() request: AuthenticatedRequest) {
    return this.liveService.startRecording(roomId, request.user);
  }

  @Post('rooms/:roomId/recording/stop')
  @UseGuards(JwtAuthGuard)
  stopRecording(@Param('roomId') roomId: string, @Req() request: AuthenticatedRequest) {
    return this.liveService.stopRecording(roomId, request.user);
  }

  @Get('rooms/:roomId/comments')
  @UseGuards(JwtAuthGuard)
  comments(@Param('roomId') roomId: string, @Req() request: AuthenticatedRequest) {
    return this.liveService.comments(roomId, request.user);
  }

  @Post('rooms/:roomId/comments')
  @UseGuards(JwtAuthGuard)
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  createComment(@Param('roomId') roomId: string, @Body() body: CreateLiveCommentDto, @Req() request: AuthenticatedRequest) {
    return this.liveService.createComment(roomId, body.body, request.user);
  }

  @Get('rooms/:roomId/reactions')
  @UseGuards(JwtAuthGuard)
  reactions(@Param('roomId') roomId: string, @Req() request: AuthenticatedRequest) {
    return this.liveService.reactions(roomId, request.user);
  }

  @Get('rooms/:roomId/settings')
  @UseGuards(JwtAuthGuard)
  settings(@Param('roomId') roomId: string) {
    return this.liveService.settings(roomId);
  }

  @Post('rooms/:roomId/reactions')
  @UseGuards(JwtAuthGuard)
  @Throttle({ default: { limit: 90, ttl: 60_000 } })
  createReaction(@Param('roomId') roomId: string, @Body() body: CreateLiveReactionDto, @Req() request: AuthenticatedRequest) {
    return this.liveService.createReaction(roomId, body.emoji, request.user);
  }

  @Post('rooms/:roomId/reports')
  @UseGuards(JwtAuthGuard)
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  reportRoom(@Param('roomId') roomId: string, @Body() body: ReportLiveRoomDto, @Req() request: AuthenticatedRequest) {
    return this.liveService.reportRoom(roomId, body.reason, request.user);
  }

  @Patch('rooms/:roomId/settings')
  @UseGuards(JwtAuthGuard)
  updateSettings(
    @Param('roomId') roomId: string,
    @Body() body: UpdateLiveSettingsDto,
    @Req() request: AuthenticatedRequest
  ) {
    return this.liveService.updateSettings(roomId, body, request.user);
  }

  @Get('rooms/:roomId/blocks')
  @UseGuards(JwtAuthGuard)
  blocks(@Param('roomId') roomId: string, @Req() request: AuthenticatedRequest) {
    return this.liveService.blocks(roomId, request.user);
  }

  @Get('rooms/:roomId/participants')
  @UseGuards(JwtAuthGuard)
  participants(@Param('roomId') roomId: string, @Req() request: AuthenticatedRequest) {
    return this.liveService.participants(roomId, request.user);
  }

  @Post('rooms/:roomId/blocks')
  @UseGuards(JwtAuthGuard)
  blockViewer(@Param('roomId') roomId: string, @Body() body: BlockViewerDto, @Req() request: AuthenticatedRequest) {
    return this.liveService.blockViewer(roomId, body.userId, request.user);
  }

  @Post('rooms/:roomId/viewer-joined')
  @UseGuards(JwtAuthGuard)
  viewerJoined(@Param('roomId') roomId: string, @Req() request: AuthenticatedRequest) {
    return this.liveService.viewerJoined(roomId, request.user);
  }

  @Post('rooms/:roomId/viewer-left')
  @UseGuards(JwtAuthGuard)
  viewerLeft(@Param('roomId') roomId: string, @Req() request: AuthenticatedRequest) {
    return this.liveService.viewerLeft(roomId, request.user);
  }

  @Delete('rooms/:roomId/blocks/:userId')
  @UseGuards(JwtAuthGuard)
  unblockViewer(@Param('roomId') roomId: string, @Param('userId') userId: string, @Req() request: AuthenticatedRequest) {
    return this.liveService.unblockViewer(roomId, userId, request.user);
  }

  @Post('token')
  @UseGuards(JwtAuthGuard)
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  createToken(@Body() body: CreateLiveTokenDto, @Req() request: AuthenticatedRequest) {
    return this.liveService.createToken(body.roomId, request.user);
  }
}
