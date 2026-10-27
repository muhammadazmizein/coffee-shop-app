# Kopi App

- `backend/`  NestJS 12 + Prisma 7 + MySQL (OTP login, menu, order, voucher, poin, webhook Midtrans)
- `admin/`    Next.js 16: panel staff/admin (papan pesanan live, riwayat & laporan penjualan, menu & opsi, voucher, outlet & kurir)
- `mobile/`   Flutter (Android, iOS, web)

## Menjalankan (development)

### Cara cepat: skrip `dev.sh`
```bash
cd ~/Apps/kopi-app
./dev.sh up       # database + backend (http://localhost:3000) + panel admin (http://localhost:3001)
./dev.sh phone    # sambungkan HP Android lewat USB, lalu jalankan app Flutter
```
Perintah lain: `./dev.sh status` (cek backend, panel, HP), `./dev.sh watch` (lihat di bawah), dan `./dev.sh down` (matikan backend dan panel; database tetap hidup).
Log: `/tmp/kopi-server.log` (backend) dan `/tmp/kopi-admin.log` (panel). Saat `flutter run` aktif: `r` hot reload, `R` hot restart, `q` keluar.

### HP Android lewat USB
1. Di HP: aktifkan Opsi pengembang (ketuk "Nomor build" 7 kali), nyalakan **Debugging USB**, dan matikan **USB tethering**.
2. Colok kabel, atur mode USB ke **Transfer file**, lalu terima kotak "Izinkan debugging USB?".
3. `./dev.sh phone` akan menjalankan `adb reverse tcp:3000 tcp:3000` sehingga `localhost:3000` di HP menunjuk ke backend di PC.
   Jalur ini putus setiap kali kabel dicabut/dicolok ulang atau HP restart (gejalanya: "Tidak dapat terhubung ke server").
   Solusi permanen: biarkan `./dev.sh watch` berjalan di satu terminal; skrip memasang ulang jalurnya otomatis begitu HP tercolok lagi
   (perintah manualnya: `~/Android/Sdk/platform-tools/adb reverse tcp:3000 tcp:3000`).

### Manual (tanpa skrip)
```bash
# 1. Database (port 3308)
podman start kopi-mysql   # atau: podman compose up -d

# 2. Backend
cd backend
npm install
npx prisma migrate deploy && npx prisma db seed
npm run start:dev          # http://localhost:3000

# 3. Panel admin
cd ../admin && npm install && npm run dev -- -p 3001      # http://localhost:3001

# 4. App
cd ../mobile
export PATH="$HOME/development/flutter/bin:$PATH"
~/Android/Sdk/platform-tools/adb reverse tcp:3000 tcp:3000
flutter run --dart-define=API_URL=http://localhost:3000   # HP USB
flutter run -d chrome                                     # web
flutter run                                               # emulator Android (otomatis 10.0.2.2:3000)
flutter run --dart-define=API_URL=http://IP-LAN:3000      # HP lewat Wi-Fi (port 3000 harus dibuka di firewall)
```

### Akun dan data uji
- OTP muncul di log backend dan di layar login (hanya saat `NODE_ENV != production`).
- Staff `081200000001` (outlet Sudirman), admin `081200000002`, voucher `HEMAT10`.
- Sebelum menguji delivery, isi koordinat outlet dengan lokasi Anda di panel **Outlet & kurir** (koordinat bawaan fiktif),
  pastikan jam buka outlet mencakup jam sekarang, dan tambah minimal satu kurir.
- Kartu uji sandbox Midtrans tidak dipakai lagi; bayar lewat simulator (lihat bagian Pembayaran).

### Masalah umum
| Gejala | Solusi |
|---|---|
| App: "Tidak dapat terhubung ke server" | `./dev.sh phone` ulang (adb reverse putus), dan cek `curl localhost:3000/outlets`. |
| `adb devices` kosong atau `unauthorized` | Cek Debugging USB, mode kabel "Transfer file", USB tethering mati, terima kotak izin di HP. |
| Backend: `RSA public key is not available` | Sudah ditangani di kode untuk koneksi lokal; restart backend. Di production pakai TLS ke database. |
| `port already in use` | `./dev.sh down`, atau matikan proses yang memegang port 3000/3001. |
| OTP SMS: backend menolak start di production | Isi `SMS_PROVIDER` dan kredensialnya (lihat bagian OTP SMS). |

### Pengujian
```bash
cd backend && npx vitest run                # test backend
cd mobile && flutter analyze && flutter test   # analyzer + test Flutter (termasuk tata letak halaman bayar)
cd mobile && SNAP_DIR=/tmp/snap flutter test test/pay_visual_test.dart   # simpan tampilan halaman bayar sebagai PNG
```

### Tema dan ilustrasi
- Warna merek (teal) ada di `mobile/lib/core/theme.dart`, `admin/app/globals.css`, dan `mobile/tool/illus.py` (ilustrasi).
- Semua ilustrasi (produk, onboarding, logo) dihasilkan oleh skrip: `cd mobile/tool && python3 gen_products.py && python3 gen_onboarding.py`.
  Pemetaan nama produk ke ilustrasi ada di `mobile/lib/widgets/illustration.dart`.
- Nama merek yang tampil di app: konstanta `appName` di `mobile/lib/core/config.dart`.

## Pengantaran (kurir kafe sendiri, tanpa pihak ketiga)
- Per outlet, admin mengatur di panel **Outlet & kurir**: jarak maksimum (km, bisa desimal; 0 = delivery mati),
  tarif dasar, batas km tarif dasar, dan tambahan per km. Default: maks 1 km.
- Alamat di luar jarak maksimum ditolak server saat quote/order, jadi app tidak bisa melewati batasnya.
- Staff memilih kurir (daftar kurir outlet) saat menandai pesanan "Diantar"; pelanggan melihat nama dan nomor kurir.
- Jarak dihitung garis lurus (haversine), bukan jarak jalan. Beri margin saat menetapkan radius.
- Nomor telepon outlet (opsional) diisi di panel **Outlet & kurir** dan tersimpan sebagai `62xxxxxxxxxx` (seluler `08xx`/`+62` dan telepon tetap seperti `(021) 555 1234` diterima; kosongkan untuk menghapus).
  Nomor ini ikut di `GET /outlets` (publik) sebagai field `phone` (null bila belum diisi) agar app bisa menampilkan tombol telepon.

## Riwayat & laporan
- Setiap perubahan status tercatat (siapa, kapan) di tabel `OrderEvent` dan tampil sebagai linimasa di detail pesanan.
- Laporan: omzet harian, jam ramai, produk terlaris, tipe/metode bayar/outlet. "Penjualan" = pesanan terbayar yang
  tidak dibatalkan. Hari dihitung zona WIB. Staff hanya melihat outletnya. Ekspor CSV maks 5.000 baris.

## OTP SMS
Atur `SMS_PROVIDER` di `backend/.env` (lihat `.env.example`). Production menolak start bila masih `console`.
Batas: 3 OTP per nomor per 10 menit dan 10 per IP per jam. Jika di belakang reverse proxy, pastikan IP klien
diteruskan dengan benar (trust proxy) agar batas per IP tidak menghitung semua orang sebagai satu IP.

## Foto produk
Admin mengunggah foto di panel **Menu** (kolom Foto): JPEG/PNG/WebP, maks 3 MB. Isi file diperiksa (bukan hanya ekstensi);
SVG ditolak. File disimpan di `backend/uploads/` dan disajikan di `/uploads/...`. Di production, folder ini harus berada di
volume persisten (atau pindahkan ke object storage seperti S3) supaya foto tidak hilang saat deploy ulang.
Selama pengembangan, 30 dari 32 menu memakai **foto stok berlisensi bebas** (22 CC0/Public Domain dari Wikimedia Commons, 8 dari Pexels License); daftar sumber dan lisensinya ada di
[docs/photo-credits.md](docs/photo-credits.md). Foto itu **wajib diganti dengan foto produk sendiri sebelum rilis** (menu tanpa foto memakai ilustrasi bawaan).

## Mengunggah foto produk sendiri secara massal
Siapkan satu folder berisi foto (jpg, jpeg, png, webp; maks 3 MB per berkas) yang **namanya sama dengan nama produk**: huruf besar/kecil, tanda `-` atau `_`,
dan aksen diabaikan. Contoh: `kopi-susu-gula-aren.jpg`, `Croissant Butter.png`, `Cookies_&_Cream.PNG`. Nama yang cocok sebagai awalan unik juga diterima
(`kopi susu.webp` -> Kopi Susu Gula Aren); nama ambigu atau tidak dikenal dilewati dan dilaporkan.
```bash
./dev.sh photos ~/foto-menu            # dry-run: hanya mencetak rencana (produk yang fotonya akan DIGANTI ditandai)
./dev.sh photos ~/foto-menu --apply    # benar-benar mengunggah
```
Isi berkas diperiksa (bukan hanya ekstensi). Tanpa `KOPI_ADMIN_TOKEN`, skrip membuat token admin sendiri dari `JWT_SECRET` lokal (hanya untuk pengembangan);
di server sungguhan isi `KOPI_ADMIN_TOKEN` dan, bila perlu, `--api https://alamat-api`. Skrip: `tool/upload-photos.mjs`.

## Promo welcome
- Layar welcome app memuat slide dari `GET /promos/welcome` (publik, maks 8, cache 60 detik). Admin mengatur di panel **Promo**:
  judul, teks, ilustrasi bawaan atau foto unggahan (JPEG/PNG/WebP ≤3 MB), tombol, kode voucher, periode tayang, urutan, aktif/nonaktif.
- Slide ber-voucher otomatis disembunyikan bila vouchernya nonaktif, berakhir, atau kuotanya habis.
- Pilihan ilustrasi bawaan ada di `backend/src/promos/promos.logic.ts` (PROMO_ART_KEYS) dan `admin/lib/promo.ts`; SVG pratinjau di `admin/public/illustrations`
  adalah salinan dari `mobile/assets/illustrations`. Menambah ilustrasi baru berarti mengubah ketiganya.

## Poin
1 poin per belanja Rp10.000 (setelah pembayaran sukses; dikali pengali level member). Penukaran: 1 poin = Rp100, maksimal 50% dari
belanja setelah voucher. Aturan ada di `backend/src/orders/pricing.ts` dan `payments.service.ts`.

## Level member
- Level (default **Member, Silver, Gold, Platinum**) ditentukan dari **total belanja terbayar seumur akun** (`User.lifetimeSpend`,
  bertambah sebesar total pesanan saat pembayaran diterima). Tidak ada penurunan level berbasis waktu; level hanya turun bila
  staff membatalkan pesanan yang sudah dibayar (belanja seumur akun ikut berkurang, tidak pernah di bawah 0).
- Default (`Tier`, bisa diubah di panel **Member**): Member Rp0 (poin 1,0×, tanpa diskon), Silver Rp500.000 (1,25×, diskon 3% maks Rp10.000),
  Gold Rp2.000.000 (1,5×, 5% maks Rp15.000), Platinum Rp5.000.000 (2,0×, 8% maks Rp25.000). Maks 6 level, level pertama selalu Rp0.
- Urutan harga di server: subtotal, diskon member, voucher, tukar poin, ongkir. Minimum belanja voucher diuji terhadap subtotal asli;
  nilai voucher dan batas 50% tukar poin dihitung dari subtotal setelah diskon member. Poin didapat = `floor(total / 10.000 x pengali%)`.
- Diskon dan pengali di-snapshot ke pesanan saat dibuat (`Order.memberDiscount`, `tierName`, `earnMultiplierPct`), sehingga quote sama dengan
  hasil akhir dan naik level akibat pesanan itu tidak memengaruhi pesanan itu sendiri.
- API: `GET /me/membership` (level, progres, daftar level), `GET/PUT /admin/tiers` (ADMIN). Laporan dan ekspor CSV memuat "Diskon member".
- Seed level default hanya membuat level yang belum ada, sehingga perubahan dari panel tidak ditimpa.

## Pembayaran (Midtrans Core API, halaman bayar buatan sendiri)
- Tidak memakai halaman Snap. App memilih metode lalu memanggil `POST /orders/:id/pay {method}`; backend membuat charge
  lewat Core API dan app menampilkan QR / deeplink / nomor VA di layar sendiri. Metode aktif: `GET /payments/methods`
  (QRIS, GoPay, ShopeePay, OVO, VA BCA/BNI/BRI/Mandiri/Permata). Matikan metode tanpa ubah kode:
  `PAYMENT_DISABLED_METHODS=ovo,shopeepay` di `backend/.env` (mis. bila belum diaktifkan di akun production).
- Satu pesanan boleh ganti metode selama belum dibayar (charge lama dibatalkan, ID Midtrans jadi `KODE-1`, `KODE-2`, ...).
  Batas bayar pesanan 30 menit sejak dibuat; pesanan yang tak dibayar dibatalkan otomatis (voucher dan poin kembali).
  Charge OVO hanya berlaku ~1 menit (push ke aplikasi OVO), jadi OVO yang habis tidak membatalkan pesanan.
- Key di `backend/.env` (tidak ikut git). Hati-hati salin client key: huruf besar `I` dan kecil `l` mirip.
- Webhook tidak bisa menjangkau localhost. Sebagai pengaman, membuka detail pesanan yang menunggu bayar menanyakan status ke
  Midtrans, dan job kedaluwarsa melakukan hal yang sama sebelum membatalkan. Untuk webhook asli saat development pakai tunnel
  (cloudflared/ngrok) dan isi Payment Notification URL di dashboard Midtrans.
- Uji di sandbox: simulator Midtrans (`simulator.sandbox.midtrans.com`) membayar QRIS/GoPay/ShopeePay lewat deeplink atau URL QR;
  `deeplinkUrl` di respons sandbox adalah halaman simulator yang bisa dibuka di browser HP. `PAYMENT_RETURN_URL`
  (default `kopiapp://payment/finish`) dipakai sebagai callback GoPay/ShopeePay.

## Profil, check-in, dan kotak masuk
- **Profil:** `GET /me` dan `PATCH /me` (nama, email, tanggal lahir `YYYY-MM-DD` umur 5-110 tahun, jenis kelamin `MALE`/`FEMALE`).
  Kelengkapan profil = 5 item x 20% (nama, email, tanggal lahir, jenis kelamin, minimal 1 alamat tersimpan).
- **Check-in harian:** `GET/POST /me/checkin`. Satu klaim per hari (hari WIB), siklus 7 hari: klaim berturut-turut menaikkan hari
  ke-1..7, melewatkan satu hari mengembalikan ke hari 1, setelah hari ke-7 kembali ke hari 1. Hadiah default 1, 1, 2, 1, 1, 2, 5 poin
  (total 13 poin = Rp1.300 per siklus penuh; 1 poin = Rp100). Admin mengubahnya di panel **Member -> Check-in harian** (0-100 poin per hari).
  Klaim ganda/serentak dijaga kunci unik database (unik per pengguna + hari): poin hanya diberikan sekali; yang kalah mendapat 409.
- **Kotak masuk:** `GET /me/notifications`, `POST /me/notifications/read-all`, `POST /me/notifications/:id/read`.
  Notifikasi dibuat otomatis untuk perubahan status pesanan (dibayar, dibuat, siap, dalam perjalanan, selesai, dibatalkan, kedaluwarsa),
  kenaikan level member, dan check-in. Pembuatannya best-effort: kegagalan notifikasi hanya dicatat di log dan tidak menggagalkan pembayaran/status pesanan.
- **Pengumuman:** admin mengirim ke semua pelanggan dari panel **Pengumuman** (`POST /admin/notifications/broadcast`). Maksimal 5 per hari per admin
  (penghitung di memori server: kembali penuh saat backend restart, dan tidak dibagi antar-instance). Setiap pengiriman dicatat di log backend.
- **Biaya dan risiko:** poin check-in bernilai uang (1 poin = Rp100). Satu orang bisa membuat banyak akun (nomor HP/OTP) untuk mengumpulkan hadiah,
  jadi jaga hadiah tetap kecil dan pantau pertambahan poin yang tidak wajar. Pengumuman tidak bisa ditarik kembali setelah terkirim.

## Akun admin di production
Seed hanya membuat akun uji (staff `081200000001`, admin `081200000002`) di mode pengembangan. Di production (`NODE_ENV=production`)
akun fiktif itu TIDAK dibuat; admin pertama dibuat dari nomor milik pemilik: `SEED_ADMIN_PHONE=081234567890 npx prisma db seed`.
Server production juga menolak start bila `JWT_SECRET` lemah (kurang dari 32 karakter atau masih teks contoh); buat dengan `openssl rand -base64 48`.

## Sebelum production
- Isi `MIDTRANS_SERVER_KEY` / `MIDTRANS_CLIENT_KEY` di `backend/.env`; daftarkan URL
  `https://DOMAIN/payments/midtrans/notify` sebagai Payment Notification URL di dashboard Midtrans.
- Ganti `JWT_SECRET`, pasang HTTPS, set `NODE_ENV=production`, `MIDTRANS_IS_PRODUCTION=true`.
- Isi kredensial SMS (Twilio atau Zenziva) dan uji kirim ke nomor asli sebelum rilis.
- Ganti application ID `id.kopiapp.kopi_app` dan ikon/nama app sesuai brand.
- Android: `flutter doctor --android-licenses`, lalu siapkan keystore untuk rilis.
