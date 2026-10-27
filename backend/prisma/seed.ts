import 'dotenv/config';
import { PrismaMariaDb } from '@prisma/adapter-mariadb';
import { PrismaClient } from '../src/generated/prisma/client.js';

const url = new URL(process.env.DATABASE_URL!);
const prisma = new PrismaClient({
  adapter: new PrismaMariaDb({
    host: url.hostname,
    port: Number(url.port || 3306),
    user: decodeURIComponent(url.username),
    password: decodeURIComponent(url.password),
    database: url.pathname.slice(1),
    allowPublicKeyRetrieval: ['127.0.0.1', 'localhost'].includes(url.hostname),
  }),
});

const sizeGroup = { name: 'Ukuran', required: true, maxSelect: 1, options: [
  { name: 'Regular', extraPrice: 0 },
  { name: 'Large', extraPrice: 4000 },
]};
const sugarGroup = { name: 'Gula', required: true, maxSelect: 1, options: [
  { name: 'Normal', extraPrice: 0 },
  { name: 'Less Sugar', extraPrice: 0 },
  { name: 'No Sugar', extraPrice: 0 },
]};
const toppingKopi = { name: 'Topping', required: false, maxSelect: 1, options: [
  { name: 'Extra Shot', extraPrice: 5000 },
]};
const toppingBoba = { name: 'Topping', required: false, maxSelect: 1, options: [
  { name: 'Boba', extraPrice: 5000 },
]};
const toppingJelly = { name: 'Topping', required: false, maxSelect: 1, options: [
  { name: 'Jelly', extraPrice: 4000 },
]};
const toppingBobaJelly = { name: 'Topping', required: false, maxSelect: 2, options: [
  { name: 'Boba', extraPrice: 5000 },
  { name: 'Jelly', extraPrice: 4000 },
]};
// Kompatibel dengan seed awal (Kopi Susu Gula Aren, Cappuccino, Matcha Latte): hanya dipakai bila produknya belum ada.
const toppingAwal = { name: 'Topping', required: false, maxSelect: 2, options: [
  { name: 'Extra Shot', extraPrice: 5000 },
  { name: 'Boba', extraPrice: 5000 },
]};
const warmGroup = { name: 'Hangatkan', required: false, maxSelect: 1, options: [
  { name: 'Ya, hangatkan', extraPrice: 0 },
]};

type Group = typeof sizeGroup;
interface Item { name: string; price: number; description: string; groups: Group[] }

// Nama produk harus persis: app memilih ilustrasi bawaan dari kata kunci pada nama.
const menu: { category: string; sort: number; products: Item[] }[] = [
  { category: 'Kopi', sort: 1, products: [
    { name: 'Kopi Susu Gula Aren', price: 22000, description: 'Espresso, susu segar, dan manis gula aren yang wangi.', groups: [sizeGroup, sugarGroup, toppingAwal] },
    { name: 'Americano', price: 18000, description: 'Espresso pekat dengan air dingin, segar dan bersih di lidah.', groups: [sizeGroup, sugarGroup] },
    { name: 'Cappuccino', price: 25000, description: 'Espresso dengan foam susu tebal yang lembut.', groups: [sizeGroup, sugarGroup, toppingAwal] },
    { name: 'Cafe Latte', price: 24000, description: 'Espresso berpadu susu creamy, ringan dan menenangkan.', groups: [sizeGroup, sugarGroup, toppingKopi] },
    { name: 'Flat White', price: 26000, description: 'Double shot espresso dengan microfoam halus, rasa kopinya terasa kuat.', groups: [sizeGroup, sugarGroup, toppingKopi] },
    { name: 'Caramel Macchiato', price: 28000, description: 'Susu, espresso, dan drizzle karamel manis yang bikin nagih.', groups: [sizeGroup, sugarGroup, toppingKopi] },
    { name: 'Mocha Latte', price: 27000, description: 'Perpaduan espresso dan cokelat pekat yang hangat di lidah.', groups: [sizeGroup, sugarGroup, toppingKopi] },
    { name: 'Hazelnut Latte', price: 27000, description: 'Latte dengan aroma kacang hazelnut yang gurih dan manis.', groups: [sizeGroup, sugarGroup, toppingKopi] },
    { name: 'Butterscotch Latte', price: 27000, description: 'Latte dengan sirup butterscotch, manis legit dan wangi mentega.', groups: [sizeGroup, sugarGroup, toppingKopi] },
    { name: 'Vietnam Drip Ice', price: 23000, description: 'Kopi tetes ala Vietnam dengan susu kental manis, disajikan dingin.', groups: [sizeGroup, sugarGroup, toppingKopi] },
    { name: 'Espresso Single', price: 15000, description: 'Satu shot espresso murni untuk pencinta kopi sejati.', groups: [sugarGroup] },
  ]},
  { category: 'Non-Kopi', sort: 2, products: [
    { name: 'Matcha Latte', price: 27000, description: 'Matcha premium dan susu, segar dengan sedikit rasa pahit yang halus.', groups: [sizeGroup, sugarGroup, toppingAwal] },
    { name: 'Chocolate', price: 24000, description: 'Cokelat pekat dan susu, manis dan lembut.', groups: [sizeGroup, sugarGroup] },
    { name: 'Taro Milk', price: 23000, description: 'Susu dengan taro ungu yang manis dan creamy.', groups: [sizeGroup, sugarGroup, toppingBoba] },
    { name: 'Red Velvet Latte', price: 25000, description: 'Susu red velvet dengan sentuhan cream cheese yang lembut.', groups: [sizeGroup, sugarGroup] },
    { name: 'Thai Tea', price: 20000, description: 'Teh Thailand dengan susu, wangi rempah dan manisnya pas.', groups: [sizeGroup, sugarGroup, toppingBobaJelly] },
    { name: 'Cookies & Cream', price: 26000, description: 'Susu dingin dengan remahan biskuit cokelat yang renyah.', groups: [sizeGroup, sugarGroup] },
    { name: 'Strawberry Milk', price: 24000, description: 'Susu segar dengan stroberi manis asam yang menyegarkan.', groups: [sizeGroup, sugarGroup, toppingBoba] },
    { name: 'Brown Sugar Boba Milk', price: 25000, description: 'Susu dengan sirup brown sugar karamel dan boba kenyal.', groups: [sizeGroup, sugarGroup, toppingJelly] },
  ]},
  { category: 'Teh & Segar', sort: 3, products: [
    { name: 'Lemon Tea', price: 18000, description: 'Teh dingin dengan perasan lemon segar, penawar haus.', groups: [sizeGroup, sugarGroup, toppingJelly] },
    { name: 'Lychee Tea', price: 20000, description: 'Teh wangi dengan buah leci manis yang menyegarkan.', groups: [sizeGroup, sugarGroup, toppingJelly] },
    { name: 'Peach Tea', price: 20000, description: 'Teh dengan rasa persik yang manis dan harum.', groups: [sizeGroup, sugarGroup, toppingJelly] },
    { name: 'Jasmine Tea Hot', price: 15000, description: 'Teh melati panas, wangi dan menenangkan.', groups: [sugarGroup] },
  ]},
  { category: 'Makanan', sort: 4, products: [
    { name: 'Croissant Butter', price: 20000, description: 'Croissant berlapis renyah dengan aroma mentega yang harum.', groups: [] },
    { name: 'Chocolate Croissant', price: 24000, description: 'Croissant renyah berisi cokelat leleh di tengahnya.', groups: [] },
    { name: 'Almond Croissant', price: 26000, description: 'Croissant dengan isian almond manis dan taburan irisan almond.', groups: [] },
    { name: 'Glazed Donut', price: 12000, description: 'Donat empuk dengan lapisan gula glaze yang manis.', groups: [] },
    { name: 'Chocolate Donut', price: 13000, description: 'Donat empuk dengan cokelat dan meises di atasnya.', groups: [] },
    { name: 'Choco Chip Cookie', price: 15000, description: 'Kukis renyah di tepi, lembut di tengah, penuh choco chip.', groups: [] },
    { name: 'Banana Bread', price: 18000, description: 'Roti pisang lembut dan lembap, manisnya alami.', groups: [warmGroup] },
    { name: 'Chicken Mayo Sandwich', price: 28000, description: 'Sandwich isi ayam, mayo, dan sayur segar.', groups: [warmGroup] },
    { name: 'Cheese Toast', price: 20000, description: 'Roti panggang dengan keju leleh yang gurih.', groups: [warmGroup] },
  ]},
];

const TIERS = [
  { name: 'Member', minSpend: 0, earnMultiplierPct: 100, discountPct: 0, maxDiscount: null, sort: 0 },
  { name: 'Silver', minSpend: 500_000, earnMultiplierPct: 125, discountPct: 3, maxDiscount: 10_000, sort: 1 },
  { name: 'Gold', minSpend: 2_000_000, earnMultiplierPct: 150, discountPct: 5, maxDiscount: 15_000, sort: 2 },
  { name: 'Platinum', minSpend: 5_000_000, earnMultiplierPct: 200, discountPct: 8, maxDiscount: 25_000, sort: 3 },
];

async function main() {
  // Level member default: hanya dibuat bila belum ada (perubahan dari panel admin tidak ditimpa).
  for (const t of TIERS) {
    await prisma.tier.upsert({ where: { name: t.name }, update: {}, create: t });
  }

  await prisma.outlet.upsert({
    where: { id: 'outlet-sudirman' }, update: {},
    create: { id: 'outlet-sudirman', name: 'Outlet Sudirman', address: 'Jl. Jenderal Sudirman, Jakarta Pusat', lat: -6.2088, lng: 106.8222, openHour: 7, closeHour: 22 },
  });
  await prisma.outlet.upsert({
    where: { id: 'outlet-kemang' }, update: {},
    create: { id: 'outlet-kemang', name: 'Outlet Kemang', address: 'Jl. Kemang Raya, Jakarta Selatan', lat: -6.2615, lng: 106.8135, openHour: 8, closeHour: 23 },
  });

  // Idempoten: kategori dicari/dibuat berdasarkan nama, produk berdasarkan nama di dalam kategori.
  // Produk yang sudah ada tidak diubah (harga/opsi yang diatur admin tidak ditimpa), hanya yang belum ada ditambahkan.
  let created = 0;
  for (const c of menu) {
    let category = await prisma.category.findFirst({ where: { name: c.category } });
    if (!category) category = await prisma.category.create({ data: { name: c.category, sort: c.sort } });
    else if (category.sort !== c.sort) category = await prisma.category.update({ where: { id: category.id }, data: { sort: c.sort } });

    for (const p of c.products) {
      if (await prisma.product.findFirst({ where: { categoryId: category.id, name: p.name } })) continue;
      await prisma.product.create({
        data: {
          categoryId: category.id, name: p.name, price: p.price, description: p.description,
          optionGroups: { create: p.groups.map((g) => ({
            name: g.name, required: g.required, maxSelect: g.maxSelect,
            options: { create: g.options },
          })) },
        },
      });
      created++;
    }
  }
  console.log(`Seed menu: ${created} produk baru ditambahkan`);

  await prisma.voucher.upsert({
    where: { code: 'HEMAT10' }, update: {},
    create: { code: 'HEMAT10', type: 'PERCENT', value: 10, minSpend: 30000, maxDiscount: 15000, quota: 1000, startsAt: new Date('2026-01-01'), endsAt: new Date('2027-12-31') },
  });

  // Slide promo welcome awal (hanya bila belum ada promo sama sekali; idempoten per judul).
  if ((await prisma.promo.count()) === 0) {
    const promos = [
      { title: 'Semua Favoritmu dalam Satu Aplikasi', body: 'Praktis pesan kopi, minuman segar, dan camilan favoritmu kapan saja.', art: 'onboarding_1', sort: 10 },
      { title: 'Diantar ke Pintu atau Ambil Sendiri', body: 'Pilih ambil di outlet, atau diantar langsung oleh kurir kami.', art: 'onboarding_2', sort: 20 },
      { title: 'Hemat 10% Pesanan Pertamamu', body: 'Pakai kode HEMAT10 untuk diskon 10% (min. belanja Rp30.000, maks Rp15.000).', art: 'product_latte', ctaLabel: 'Pakai voucher', voucherCode: 'HEMAT10', sort: 30 },
    ];
    for (const p of promos) {
      if (!(await prisma.promo.findFirst({ where: { title: p.title } }))) await prisma.promo.create({ data: p });
    }
    console.log(`Seed promo: ${promos.length} slide welcome ditambahkan`);
  }

  // Hadiah check-in harian default (1 poin = Rp100, sengaja kecil). Tidak menimpa nilai yang sudah diubah admin.
  for (const [day, points] of [[1, 1], [2, 1], [3, 2], [4, 1], [5, 1], [6, 2], [7, 5]] as const) {
    await prisma.checkInReward.upsert({ where: { day }, update: {}, create: { day, points } });
  }

  if (process.env.NODE_ENV === 'production') {
    // Production: TIDAK membuat akun uji fiktif (nomor yang bisa dimiliki orang lain = akses admin).
    // Admin pertama dibuat dari nomor milik pemilik lewat SEED_ADMIN_PHONE (mis. 081234567890).
    const raw = (process.env.SEED_ADMIN_PHONE ?? '').replace(/\D/g, '');
    const phone = raw.startsWith('0') ? '62' + raw.slice(1) : raw;
    if (/^628\d{8,11}$/.test(phone)) {
      await prisma.user.upsert({ where: { phone }, update: { role: 'ADMIN' }, create: { phone, name: 'Admin', role: 'ADMIN' } });
      console.log(`Admin production dibuat/diperbarui untuk ${phone.slice(0, 5)}****${phone.slice(-3)}`);
    } else {
      console.warn('SEED_ADMIN_PHONE belum diisi atau tidak valid: tidak ada akun admin yang dibuat.');
    }
  } else {
    // Pengembangan lokal: akun uji (login OTP dengan nomor ini; kode OTP tampil di layar/log dalam mode dev)
    await prisma.user.upsert({
      where: { phone: '6281200000001' }, update: {},
      create: { phone: '6281200000001', name: 'Barista Sudirman', role: 'STAFF', outletId: 'outlet-sudirman' },
    });
    await prisma.user.upsert({
      where: { phone: '6281200000002' }, update: {},
      create: { phone: '6281200000002', name: 'Admin', role: 'ADMIN' },
    });
  }
}

main().finally(() => prisma.$disconnect());
