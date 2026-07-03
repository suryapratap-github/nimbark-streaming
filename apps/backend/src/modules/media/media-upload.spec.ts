import { BadRequestException } from '@nestjs/common';
import { StorageProvider } from '@prisma/client';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { CreateUploadDto } from './dto/create-upload.dto';
import { StorageService } from '../storage/storage.service';

describe('media upload validation', () => {
  it('accepts valid upload creation payloads', async () => {
    const dto = plainToInstance(CreateUploadDto, {
      fileName: 'clip.mp4',
      contentType: 'video/mp4'
    });

    await expect(validate(dto)).resolves.toHaveLength(0);
  });

  it('rejects missing file names or content types', async () => {
    const dto = plainToInstance(CreateUploadDto, {
      fileName: '',
      contentType: ''
    });

    const errors = await validate(dto);
    expect(errors.map((error) => error.property)).toEqual(expect.arrayContaining(['fileName', 'contentType']));
  });

  it('creates local upload requests with sanitized object keys', async () => {
    jest.spyOn(Date, 'now').mockReturnValue(1234);
    const prisma = {
      storageSetting: {
        upsert: jest.fn().mockResolvedValue({
          id: 'default',
          provider: StorageProvider.LOCAL,
          localBasePath: 'storage/media',
          localPublicUrl: '/api/media/local',
          videoCompressionEnabled: false,
          r2Bucket: null,
          r2Endpoint: null,
          r2Region: 'auto',
          r2AccessKeyId: null,
          r2SecretKey: null,
          r2PublicUrl: null,
          updatedAt: new Date()
        })
      }
    };
    const service = new StorageService(prisma as never);

    await expect(service.createUpload('../bad file.mp4', 'video/mp4')).resolves.toMatchObject({
      provider: StorageProvider.LOCAL,
      objectKey: 'uploads/1234-..-bad-file.mp4',
      uploadUrl: '/api/media/local-upload',
      publicUrl: '/api/media/local/uploads/1234-..-bad-file.mp4',
      method: 'POST',
      fieldName: 'file'
    });
  });

  it('rejects local path traversal attempts', () => {
    const service = new StorageService({} as never);

    expect(() => service.localPath('storage/media', '../../secret.mp4')).toThrow(BadRequestException);
  });

  it('rejects R2 uploads until required storage settings are configured', async () => {
    const prisma = {
      storageSetting: {
        upsert: jest.fn().mockResolvedValue({
          id: 'default',
          provider: StorageProvider.R2,
          localBasePath: 'storage/media',
          localPublicUrl: '/api/media/local',
          videoCompressionEnabled: false,
          r2Bucket: null,
          r2Endpoint: null,
          r2Region: 'auto',
          r2AccessKeyId: null,
          r2SecretKey: null,
          r2PublicUrl: null,
          updatedAt: new Date()
        })
      }
    };
    const service = new StorageService(prisma as never);

    await expect(service.createUpload('clip.mp4', 'video/mp4')).rejects.toBeInstanceOf(BadRequestException);
  });
});
