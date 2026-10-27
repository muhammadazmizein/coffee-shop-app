#!/usr/bin/env node
// Unggah foto produk secara massal: mencocokkan NAMA BERKAS dengan NAMA PRODUK lalu mengunggah lewat API admin.
//
//   node tool/upload-photos.mjs <folder> [--apply] [--api http://localhost:3000]
//   ./dev.sh photos <folder> [--apply]
//
// Tanpa --apply hanya mencetak rencana (dry-run). Penamaan berkas, contoh: kopi-susu-gula-aren.jpg, Croissant Butter.png
// Token admin: env KOPI_ADMIN_TOKEN; bila tidak ada, skrip membuat token sendiri dari JWT_SECRET backend (HANYA untuk pengembangan lokal).

import { createRequire } from 'node:module';
import { readFile, readdir, stat } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const MAX_BYTES = 3 * 1024 * 1024;
const EXT = new Map([['.jpg', 'image/jpeg'], ['.jpeg', 'image/jpeg'], ['.png', 'image/png'], ['.webp', 'image/webp']]);
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

/** Normalisasi nama untuk pencocokan: huruf kecil, tanpa ekstensi/aksen/simbol, `-` dan `_` jadi spasi. */
export function normalize(name) {
  return name
    .replace(/\.[a-z0-9]+$/i, '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[-_]+/g, ' ')
    .replace(/&/g, ' dan ')
    .replace(/[^a-z0-9 ]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/** Cocok persis, atau berawalan yang unik (mis. "kopi susu" -> satu-satunya produk berawalan itu). */
export function matchProduct(fileBase, products) {
  const key = normalize(fileBase);
  if (!key) return { error: 'nama berkas kosong setelah dinormalisasi' };
  const exact = products.filter((p) => normalize(p.name) === key);
  if (exact.length === 1) return { product: exact[0], how: 'persis' };
  if (exact.length > 1) return { error: `ambigu: ${exact.map((p) => p.name).join(', ')}` };
  const prefix = products.filter((p) => normalize(p.name).startsWith(key + ' ') || normalize(p.name).startsWith(key));
  if (prefix.length === 1) return { product: prefix[0], how: 'awalan unik' };
  if (prefix.length > 1) return { error: `ambigu (awalan): ${prefix.map((p) => p.name).join(', ')}` };
  return { error: 'tidak ada produk dengan nama itu' };
}

/** Tipe sebenarnya dari isi berkas (bukan ekstensi); null bila bukan JPEG/PNG/WebP. */
export function sniffType(buf) {
  if (buf.length >= 3 && buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return 'image/jpeg';
  if (buf.length >= 8 && buf.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return 'image/png';
  if (buf.length >= 12 && buf.subarray(0, 4).toString('latin1') === 'RIFF' && buf.subarray(8, 12).toString('latin1') === 'WEBP') return 'image/webp';
  return null;
}

async function getToken() {
  if (process.env.KOPI_ADMIN_TOKEN) return process.env.KOPI_ADMIN_TOKEN;
  const envFile = path.join(root, 'backend', '.env');
  if (!existsSync(envFile)) throw new Error('KOPI_ADMIN_TOKEN belum diisi dan backend/.env tidak ditemukan.');
  const line = (await readFile(envFile, 'utf8')).split('\n').find((l) => l.startsWith('JWT_SECRET='));
  const secret = line?.slice('JWT_SECRET='.length).trim().replace(/^["']|["']$/g, '');
  if (!secret) throw new Error('JWT_SECRET tidak ada di backend/.env.');
  const jwt = createRequire(path.join(root, 'backend', 'package.json'))('jsonwebtoken');
  console.warn('PERINGATAN: membuat token admin sendiri dari JWT_SECRET lokal (hanya untuk pengembangan). Di server sungguhan pakai KOPI_ADMIN_TOKEN.');
  return jwt.sign({ sub: 'upload-photos-script', role: 'ADMIN' }, secret, { expiresIn: '30m' });
}

async function main() {
  const args = process.argv.slice(2);
  const apply = args.includes('--apply');
  const apiIdx = args.indexOf('--api');
  const api = (apiIdx >= 0 ? args[apiIdx + 1] : process.env.KOPI_API_URL ?? 'http://localhost:3000').replace(/\/$/, '');
  const folder = args.find((a, i) => !a.startsWith('--') && args[i - 1] !== '--api');
  if (!folder) {
    console.error('Pemakaian: node tool/upload-photos.mjs <folder> [--apply] [--api URL]');
    process.exit(2);
  }
  if (!existsSync(folder) || !(await stat(folder)).isDirectory()) {
    console.error(`Folder tidak ditemukan: ${folder}`);
    process.exit(2);
  }

  const token = await getToken();
  const headers = { Authorization: `Bearer ${token}` };
  const res = await fetch(`${api}/admin/products`, { headers }).catch((e) => {
    throw new Error(`Tidak dapat menghubungi ${api} (${e.message}). Apakah backend hidup? Coba ./dev.sh up`);
  });
  if (!res.ok) throw new Error(`GET /admin/products gagal (${res.status}). Token admin tidak valid?`);
  const products = await res.json();

  const files = (await readdir(folder)).filter((f) => !f.startsWith('.')).sort();
  const plan = [];
  const claimed = new Map(); // product.id -> nama berkas yang sudah memakainya

  for (const f of files) {
    const full = path.join(folder, f);
    const ext = path.extname(f).toLowerCase();
    if (!(await stat(full)).isFile()) continue;
    if (!EXT.has(ext)) {
      plan.push({ file: f, status: 'LEWATI', reason: `ekstensi ${ext || '(kosong)'} tidak didukung (jpg, jpeg, png, webp)` });
      continue;
    }
    const m = matchProduct(f, products);
    if (m.error) {
      plan.push({ file: f, status: 'LEWATI', reason: m.error });
      continue;
    }
    const size = (await stat(full)).size;
    if (size > MAX_BYTES) {
      plan.push({ file: f, status: 'LEWATI', reason: `terlalu besar (${(size / 1048576).toFixed(1)} MB > 3 MB)` });
      continue;
    }
    const buf = await readFile(full);
    const real = sniffType(buf);
    if (!real) {
      plan.push({ file: f, status: 'LEWATI', reason: 'isi berkas bukan JPEG/PNG/WebP yang valid' });
      continue;
    }
    if (claimed.has(m.product.id)) {
      plan.push({ file: f, status: 'LEWATI', reason: `produk "${m.product.name}" sudah dipakai berkas ${claimed.get(m.product.id)}` });
      continue;
    }
    claimed.set(m.product.id, f);
    plan.push({ file: f, status: 'UNGGAH', product: m.product, how: m.how, buf, type: real, replaces: Boolean(m.product.imageUrl) });
  }

  console.log(apply ? 'MENGUNGGAH:' : 'RENCANA (dry-run; tambahkan --apply untuk mengunggah):');
  for (const p of plan) {
    if (p.status === 'UNGGAH') console.log(`  ✔ ${p.file}  →  ${p.product.name}  [${p.how}${p.replaces ? ', MENGGANTI foto lama' : ''}]`);
    else console.log(`  ✘ ${p.file}  —  ${p.reason}`);
  }

  const todo = plan.filter((p) => p.status === 'UNGGAH');
  const skipped = plan.length - todo.length;
  if (!apply) {
    console.log(`\n${todo.length} berkas siap diunggah, ${skipped} dilewati. Jalankan ulang dengan --apply.`);
    return;
  }

  let ok = 0;
  let fail = 0;
  for (const p of todo) {
    const form = new FormData();
    form.append('file', new Blob([p.buf], { type: p.type }), p.file);
    const r = await fetch(`${api}/admin/products/${p.product.id}/image`, { method: 'POST', headers, body: form });
    if (r.ok) {
      ok++;
      console.log(`  ↑ ${p.file} → ${p.product.name}: berhasil`);
    } else {
      fail++;
      const msg = await r.text().catch(() => '');
      console.log(`  ✘ ${p.file} → ${p.product.name}: gagal (${r.status}) ${msg.slice(0, 160)}`);
    }
  }
  console.log(`\nSelesai: ${ok} berhasil, ${fail} gagal, ${skipped} dilewati.`);
  if (fail > 0) process.exit(1);
}

// Hanya jalan bila dipanggil langsung (bukan saat diimpor untuk test).
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch((e) => {
    console.error('Galat:', e.message);
    process.exit(1);
  });
}
