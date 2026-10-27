import { describe, expect, it } from 'vitest';
import { detectImage } from './image.js';

const png = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0]);
const jpg = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0, 0x10]);
const webp = Buffer.concat([Buffer.from('RIFF'), Buffer.from([1, 0, 0, 0]), Buffer.from('WEBPVP8 ')]);

describe('detectImage', () => {
  it('mengenali PNG, JPEG, WebP dari isi file', () => {
    expect(detectImage(png)?.ext).toBe('png');
    expect(detectImage(jpg)?.ext).toBe('jpg');
    expect(detectImage(webp)?.ext).toBe('webp');
  });
  it('menolak SVG, teks, dan file kosong/terlalu pendek', () => {
    expect(detectImage(Buffer.from('<svg xmlns="http://www.w3.org/2000/svg"></svg>'))).toBeNull();
    expect(detectImage(Buffer.from('halo ini bukan gambar'))).toBeNull();
    expect(detectImage(Buffer.alloc(0))).toBeNull();
    expect(detectImage(Buffer.from([0xff, 0xd8]))).toBeNull();
  });
  it('RIFF tanpa WEBP (mis. WAV) ditolak', () => {
    expect(detectImage(Buffer.concat([Buffer.from('RIFF'), Buffer.from([1, 0, 0, 0]), Buffer.from('WAVEfmt ')]))).toBeNull();
  });
});
