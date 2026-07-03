import { Body, Controller, Get, Param, Post, Res, UploadedFile, UseGuards, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { Throttle } from '@nestjs/throttler';
import type { Response } from 'express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CreateMediaAssetDto } from './dto/create-media-asset.dto';
import { CreateUploadDto } from './dto/create-upload.dto';
import { MediaService } from './media.service';

@Controller('media')
export class MediaController {
  constructor(private readonly mediaService: MediaService) {}

  @Get('settings')
  settings() {
    return this.mediaService.settings();
  }

  @Post('uploads')
  @UseGuards(JwtAuthGuard)
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  createUpload(@Body() body: CreateUploadDto) {
    return this.mediaService.createUpload(body.fileName, body.contentType);
  }

  @Post('local-upload')
  @UseGuards(JwtAuthGuard)
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  @UseInterceptors(FileInterceptor('file'))
  uploadLocalFile(@UploadedFile() file: { originalname: string; mimetype: string; size: number; buffer: Buffer }) {
    return this.mediaService.saveLocalUpload(file);
  }

  @Get('local/:path(*)')
  async localFile(@Param('path') objectKey: string, @Res() response: Response) {
    const filePath = await this.mediaService.localFilePath(objectKey);
    response.sendFile(filePath);
  }

  @Post('assets')
  @UseGuards(JwtAuthGuard)
  createAsset(@Body() body: CreateMediaAssetDto) {
    return this.mediaService.createAsset(body);
  }
}
