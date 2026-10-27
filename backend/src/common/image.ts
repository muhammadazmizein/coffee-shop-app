import { randomUUID } from 'node:crypto';
import { mkdir, unlink, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { BadRequestException } from '@nestjs/common';

export const UPLOAD_DIR = path.resolve(process.cwd(), 'uploads');
export const MAX_IMAGE_BYTES = 3 * 1024 * 1024;

export interface DetectedImage {
  ext: 'jpg' | 'png' | 'webp';
  mime: string;
}

/** Deteksi tipe gambar dari isi file (magic bytes). Mimetype dan ekstensi dari client tidak dipercaya; SVG dan lainnya ditolak. */
export function detectImage(buf: Buffer): DetectedImage | null {
  if (buf.length >= 3 && buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return { ext: 'jpg', mime: 'image/jpeg' };
  if (buf.length >= 8 && buf.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) {
    return { ext: 'png', mime: 'image/png' };
  }
  if (buf.length >= 12 && buf.toString('ascii', 0, 4) === 'RIFF' && buf.toString('ascii', 8, 12) === 'WEBP') {
    return { ext: 'webp', mime: 'image/webp' };
  }
  return null;
}

const STORED_URL = /^\/uploads\/[A-Za-z0-9-]+\.(jpg|png|webp)$/;

/** Hapus file foto lama berdasarkan imageUrl; hanya file di dalam folder uploads yang boleh dihapus. */
export async function removeStoredImage(imageUrl: string | null | undefined): Promise<void> {
  if (!imageUrl || !STORED_URL.test(imageUrl)) return;
  const target = path.resolve(UPLOAD_DIR, path.basename(imageUrl));
  if (path.dirname(target) !== UPLOAD_DIR) return;
  await unlink(target).catch((e: NodeJS.ErrnoException) => {
    if (e.code !== 'ENOENT') throw e;
  });
}

/**
 * Validasi file unggahan (isi file, bukan ekstensi/mimetype) lalu simpan ke folder uploads dengan nama acak.
 * Mengembalikan imageUrl relatif ("/uploads/<nama>"). Melempar 400 bila file kosong atau bukan JPEG/PNG/WebP.
 */
export async function saveUploadedImage(file?: { buffer: Buffer }): Promise<string> {
  if (!file) throw new BadRequestException('File foto wajib diunggah (field "file")');
  const type = detectImage(file.buffer);
  if (!type) throw new BadRequestException('Format foto harus JPEG, PNG, atau WebP');
  const name = `${randomUUID()}.${type.ext}`;
  await mkdir(UPLOAD_DIR, { recursive: true });
  await writeFile(path.join(UPLOAD_DIR, name), file.buffer, { flag: 'wx' });
  return `/uploads/${name}`;
}
