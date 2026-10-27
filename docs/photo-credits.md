# Kredit foto produk (foto stok untuk pengembangan)

> **Foto-foto ini hanya stok untuk tahap pengembangan.** Sebelum rilis, **WAJIB diganti dengan foto produk milik sendiri**
> (unggah lewat panel admin → Menu → kolom Foto). Foto stok bukan foto menu kita sehingga bisa menyesatkan pelanggan.

- Sumber putaran 1: Wikimedia Commons (diambil lewat API resmi MediaWiki, 2026-10-26). Sumber putaran 2: Pexels (lihat tabel kedua di bawah, 2026-10-27).
- Lisensi yang dipakai: hanya **CC0** dan **Public Domain**, sehingga tidak ada kewajiban atribusi. Pembuat tetap dicatat di bawah sebagai itikad baik.
- Pengolahan: setiap foto dipotong atau diberi bantalan ke persegi, diperkecil maks 1000 px, dan disimpan sebagai JPEG kualitas ~82
  (semua <= 230 KB). Tidak ada retus warna atau penambahan elemen.
- Terpasang pada **30 dari 32 produk** (22 dari Wikimedia Commons, 8 dari Pexels). Dua produk tetap memakai ilustrasi bawaan karena tidak ada foto
  berlisensi bebas yang cocok secara jujur: **Caramel Macchiato** (foto yang ditemukan tidak menunjukkan minuman berlapis dengan siraman karamel; satu kandidat terlalu gelap)
  dan **Red Velvet Latte** (tidak ada foto minuman red velvet latte; hasil hanya koktail atau kue).
- Foto disimpan di `backend/uploads/` dan terhubung ke produk lewat `Product.imageUrl`. Menghapus/mengganti foto di panel menghapus berkasnya.

| Produk | Berkas sumber (Commons) | Lisensi | Pembuat | Pengolahan / catatan kecocokan |
|---|---|---|---|---|
| Almond Croissant | [Almond croissant - Auckland, New Zealand.jpg](https://commons.wikimedia.org/wiki/File:Almond_croissant_-_Auckland,_New_Zealand.jpg) | CC0 | Daderot | dipotong persegi; Croissant almond (dipotong dekat, tampak seperti tumpukan serpihan almond). |
| Banana Bread | [Banana bread toasted with butter - Tilt 2024-03-29.jpg](https://commons.wikimedia.org/wiki/File:Banana_bread_toasted_with_butter_-_Tilt_2024-03-29.jpg) | CC0 | Andy Li | dipotong persegi; Irisan banana bread berlatar gelap; tepi atas masih memuat sedikit lengan di pojok. |
| Brown Sugar Boba Milk | [Pearl Milk Tea in Chun Shui Tang.jpg](https://commons.wikimedia.org/wiki/File:Pearl_Milk_Tea_in_Chun_Shui_Tang.jpg) | CC0 | Battlesnake1 | dipotong persegi; Pearl milk tea berisi tapioka; bukan khusus brown sugar. |
| Cafe Latte | [Two Hands Cafe latte art (Unsplash).jpg](https://commons.wikimedia.org/wiki/File:Two_Hands_Cafe_latte_art_(Unsplash).jpg) | CC0 | Drew Coffman drewcoffman | dipotong persegi |
| Cappuccino | [Cappuccino - Wai Kika Moo Kau 2024-01-13.jpg](https://commons.wikimedia.org/wiki/File:Cappuccino_-_Wai_Kika_Moo_Kau_2024-01-13.jpg) | CC0 | Andy Li | dipotong persegi; Cappuccino bertabur kakao dari atas. |
| Cheese Toast | [Grilled cheese sandwiches.jpg](https://commons.wikimedia.org/wiki/File:Grilled_cheese_sandwiches.jpg) | Public domain | Jon Sullivan | dipotong persegi; Grilled cheese sandwich bertumpuk; dipotong agar botol di latar tidak terlihat. |
| Chicken Mayo Sandwich | [Snais's Sandwich (toasted) - Snais's Cafe 2025-12-19 (1).jpg](https://commons.wikimedia.org/wiki/File:Snais%27s_Sandwich_(toasted)_-_Snais%27s_Cafe_2025-12-19_(1).jpg) | CC0 | Andy Li | dipotong persegi; Sandwich panggang potong segitiga; isian ayamnya tidak bisa diverifikasi dari foto (representasi generik). |
| Choco Chip Cookie | [Choc-Chip-Cookie.jpg](https://commons.wikimedia.org/wiki/File:Choc-Chip-Cookie.jpg) | Public domain | Evan-Amos | diberi bantalan putih ke persegi |
| Chocolate | [Hot Chocolate (Unsplash).jpg](https://commons.wikimedia.org/wiki/File:Hot_Chocolate_(Unsplash).jpg) | CC0 | Patrycja Polechonska ppolecho | dipotong persegi; Hot chocolate berkrim kocok; menu kita bisa dipesan dingin (representasi generik). |
| Chocolate Croissant | [Pain au chocolat - Milfey Patisserie 2026-09-30.jpg](https://commons.wikimedia.org/wiki/File:Pain_au_chocolat_-_Milfey_Patisserie_2026-09-30.jpg) | CC0 | Andy Li | dipotong persegi |
| Chocolate Donut | [Chocolate-glazed doughnut (1236451).jpg](https://commons.wikimedia.org/wiki/File:Chocolate-glazed_doughnut_(1236451).jpg) | CC0 | Unknown authorUnknown author | diberi bantalan putih ke persegi |
| Croissant Butter | [Croissant-Petr Kratochvil.jpg](https://commons.wikimedia.org/wiki/File:Croissant-Petr_Kratochvil.jpg) | CC0 | Petr Kratochvil | diberi bantalan putih ke persegi |
| Espresso Single | [Espresso Coffee 01.jpg](https://commons.wikimedia.org/wiki/File:Espresso_Coffee_01.jpg) | CC0 | Jubair1985 | dipotong persegi |
| Glazed Donut | [Glazed doughnut (1387303).jpg](https://commons.wikimedia.org/wiki/File:Glazed_doughnut_(1387303).jpg) | CC0 | Unknown authorUnknown author | diberi bantalan putih ke persegi |
| Kopi Susu Gula Aren | [Iced Coffee Cream Latte - CK Bistro 2024-06-23.jpg](https://commons.wikimedia.org/wiki/File:Iced_Coffee_Cream_Latte_-_CK_Bistro_2024-06-23.jpg) | CC0 | Andy Li | dipotong persegi; Kopi susu es berlapis dengan busa; bukan khusus gula aren (representasi generik). |
| Lemon Tea | [Iced lemon tea - Rawlab Juice & Tea.jpg](https://commons.wikimedia.org/wiki/File:Iced_lemon_tea_-_Rawlab_Juice_%26_Tea.jpg) | CC0 | Andy Li | dipotong persegi |
| Lychee Tea | [Iced lychee tea and Es teh manis - Bali 2025-09-25.jpg](https://commons.wikimedia.org/wiki/File:Iced_lychee_tea_and_Es_teh_manis_-_Bali_2025-09-25.jpg) | CC0 | Andy Li | dipotong persegi; Foto asli memuat dua gelas; dipotong ke gelas lychee (sisa sedikit gelas kedua di tepi). |
| Matcha Latte | [Iced green tea latte.jpg](https://commons.wikimedia.org/wiki/File:Iced_green_tea_latte.jpg) | CC0 | Saya1611 | dipotong persegi |
| Mocha Latte | [Iced Mocha - Granny's Café 2024-08-21.jpg](https://commons.wikimedia.org/wiki/File:Iced_Mocha_-_Granny%27s_Caf%C3%A9_2024-08-21.jpg) | CC0 | Andy Li | dipotong persegi; Iced mocha. |
| Strawberry Milk | [Strawberry milk shake.jpg](https://commons.wikimedia.org/wiki/File:Strawberry_milk_shake.jpg) | Public domain | Renee Comet (Photographer) | dipotong persegi; Strawberry milk shake berlatar putih (representasi untuk 'Strawberry Milk'). |
| Taro Milk | [Taro flavored milk tea.jpg](https://commons.wikimedia.org/wiki/File:Taro_flavored_milk_tea.jpg) | CC0 | Fumikas Sagisavas | dipotong persegi; Dipegang tangan; ada sedikit tepi logo cangkir yang tidak terbaca. Ganti dengan foto sendiri. |
| Thai Tea | [Thai Red Ice Milk Tea - Siam Siam 2024-07-31.jpg](https://commons.wikimedia.org/wiki/File:Thai_Red_Ice_Milk_Tea_-_Siam_Siam_2024-07-31.jpg) | CC0 | Andy Li | dipotong persegi; Thai red ice milk tea; sudah dipotong agar orang di latar tidak terlihat. |

## Putaran 2: foto dari Pexels (2026-10-27)

Lisensi semua baris: **Pexels License** (tertulis di tiap halaman foto: https://www.pexels.com/license/), yang mengizinkan penggunaan komersial tanpa atribusi.
Pembuat tetap dicatat sebagai itikad baik. Tiap foto diunduh satu per satu dari halaman fotonya dengan jeda; situs yang memblokir unduhan otomatis
(Pixabay 403, Unsplash 401, sebagian halaman Pexels 403) dilewati tanpa upaya mengakalinya. Pengolahan: dipotong persegi, 800-1000 px, JPEG kualitas ~82-84 (semua <= 150 KB).

| Produk | Halaman sumber | Pembuat | Catatan kecocokan (jujur) |
|---|---|---|---|
| Americano | [pexels.com/photo/cold-coffee-in-glass-on-table-17576001](https://www.pexels.com/photo/cold-coffee-in-glass-on-table-17576001/) | Abeer H | Kopi hitam di atas es dalam gelas bergelombang; sesuai Americano es. |
| Flat White | [pexels.com/photo/flat-lay-photography-of-cup-of-coffee-459476](https://www.pexels.com/photo/flat-lay-photography-of-cup-of-coffee-459476/) | "Pixabay" (nama pembuat seperti tertulis di Pexels) | Cangkir dengan latte art tulip, dipegang dua tangan berkaus rajut (tanpa wajah), ujung buku catatan terlihat. Latte art generik, bukan flat white terverifikasi. |
| Hazelnut Latte | [pexels.com/photo/iced-latte-in-glass-11136849](https://www.pexels.com/photo/iced-latte-in-glass-11136849/) | Federica Gioia | Latte es berlapis di gelas kaca. Generik: tidak menunjukkan rasa hazelnut. |
| Butterscotch Latte | [pexels.com/photo/a-glass-of-iced-coffee-8605859](https://www.pexels.com/photo/a-glass-of-iced-coffee-8605859/) | solod_sha Content creator | Kopi susu es berwarna karamel dengan tumpahan. Generik: tidak menunjukkan rasa butterscotch. |
| Vietnam Drip Ice | [pexels.com/photo/coffee-with-ice-cubes-14802987](https://www.pexels.com/photo/coffee-with-ice-cubes-14802987/) | Teresa Jang | Kopi susu es berlapis (susu di bawah) di gelas bergaris. Mirip penyajian kopi susu kental, tetapi bukan penyajian dengan phin. |
| Cookies & Cream | [pexels.com/photo/chocolate-milkshake-3727250](https://www.pexels.com/photo/chocolate-milkshake-3727250/) | Horizon Content | Milkshake kue cokelat dengan kue sandwich cokelat di piring; ada hiasan stroberi yang tidak ada di menu kita. Kue tidak memuat teks merek yang terbaca. |
| Peach Tea | [pexels.com/photo/peach-juice-with-ice-17525264](https://www.pexels.com/photo/peach-juice-with-ice-17525264/) | Büşra İnce | Minuman persik es dengan mint dan irisan persik. Judul sumber "peach juice": bisa jus atau teh persik. |
| Jasmine Tea Hot | [pexels.com/photo/cup-of-aromatic-jasmine-tea-served-on-table-in-garden-7138780](https://www.pexels.com/photo/cup-of-aromatic-jasmine-tea-served-on-table-in-garden-7138780/) | Julia Filirovska | Cangkir kaca teh melati keemasan dengan bunga melati dan uap; sangat sesuai. |

Kandidat yang dinilai dan **ditolak**: 10484519 (koktail kupe di bar, menyesatkan untuk Red Velvet Latte), 18006786 (terlalu gelap, tidak terlihat karamel),
11976961 (logo merek terbaca jelas di cangkir), 8330322 (teko teh; tidak dibutuhkan).
