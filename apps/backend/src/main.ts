import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestExpressApplication } from '@nestjs/platform-express';
import { NestFactory } from '@nestjs/core';
import { mkdirSync } from 'fs';
import { resolve } from 'path';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule, { rawBody: true });
  const config = app.get(ConfigService);
  const corsOrigin = config.get<string>('CORS_ORIGIN') ?? '*';
  const configuredOrigins = corsOrigin.split(',').map((origin) => origin.trim()).filter(Boolean);
  const localOrigins =
    config.get<string>('NODE_ENV') === 'development'
      ? ['http://localhost:5173', 'http://127.0.0.1:5173']
      : [];
  const allowedOrigins =
    corsOrigin === '*' ? true : Array.from(new Set([...configuredOrigins, ...localOrigins]));

  app.enableCors({ origin: allowedOrigins, credentials: true });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true
    })
  );
  app.setGlobalPrefix('api');
  const localMediaPath = resolve(process.cwd(), config.get<string>('LOCAL_STORAGE_PATH') ?? 'storage/media');
  mkdirSync(localMediaPath, { recursive: true });
  app.useStaticAssets(localMediaPath, { prefix: '/media-local/' });

  const port = config.get<number>('PORT') ?? 4000;
  await app.listen(port);
}

void bootstrap();
