import 'dotenv/config';
import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import type { NestExpressApplication } from '@nestjs/platform-express';
import { AppModule } from './app.module.js';
import { assertStrongJwtSecret } from './common/security.js';
import { UPLOAD_DIR } from './common/image.js';

async function bootstrap() {
  for (const key of ['DATABASE_URL', 'JWT_SECRET']) {
    if (!process.env[key]) throw new Error(`Env ${key} belum diisi`);
  }
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  // Foto produk: nosniff mencegah browser menebak tipe; CORP cross-origin agar panel (port/domain lain) bisa menampilkannya.
  app.useStaticAssets(UPLOAD_DIR, {
    prefix: '/uploads',
    index: false,
    dotfiles: 'deny',
    maxAge: '7d',
    immutable: true,
    setHeaders: (res) => {
      res.setHeader('X-Content-Type-Options', 'nosniff');
      res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
    },
  });
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
  app.enableCors();
  await app.listen(process.env.PORT ?? 3000);
}
await bootstrap();
