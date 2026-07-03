import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../database/prisma.service';
import { StorageService } from '../storage/storage.service';
import { CreateMediaAssetDto } from './dto/create-media-asset.dto';

@Injectable()
export class MediaService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService
  ) {}

  createAsset(dto: CreateMediaAssetDto) {
    return this.prisma.mediaAsset.create({
      data: dto
    });
  }

  settings() {
    return this.storage.settings();
  }

  async createUpload(fileName: string, contentType: string) {
    return this.storage.createUpload(fileName, contentType);
  }

  async saveLocalUpload(file: { originalname: string; mimetype: string; size: number; buffer: Buffer }) {
    return this.storage.saveLocalObject(file);
  }

  async localFilePath(objectKey: string) {
    try {
      return await this.storage.localFilePath(objectKey);
    } catch (error) {
      if (error instanceof BadRequestException) {
        throw error;
      }

      throw new NotFoundException('Local media file not found');
    }
  }
}
