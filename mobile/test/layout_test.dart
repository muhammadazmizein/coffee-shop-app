import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopi_app/core/theme.dart';
import 'package:kopi_app/models/models.dart';
import 'package:kopi_app/screens/home_screen.dart';
import 'package:kopi_app/state/favorites.dart';
import 'package:kopi_app/state/providers.dart';

/// Menjaga tata letak: setiap tab dirender pada beberapa ukuran layar dan skala font, dengan data sengaja panjang.
/// Flutter melempar error saat ada "BOTTOM OVERFLOWED", sehingga test ini gagal bila ada yang meluap.
/// Bila env SNAP_DIR diisi, hasil render disimpan sebagai PNG.
final _fonts = '${Platform.environment['HOME']}/development/flutter/bin/cache/artifacts/material_fonts';

Future<void> _loadRoboto() async {
  final loader = FontLoader('Roboto');
  for (final f in ['Regular', 'Medium', 'Bold', 'Black']) {
    final file = File('$_fonts/Roboto-$f.ttf');
    if (file.existsSync()) loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await loader.load();
  // Font merek (sama dengan app) supaya render dan ukuran teks mendekati kenyataan.
  final poppins = FontLoader('Poppins');
  for (final f in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final file = File('assets/fonts/Poppins-$f.ttf');
    if (file.existsSync()) poppins.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await poppins.load();
  final icons = File('$_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final i = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await i.load();
  }
}

final _outlet = Outlet(id: 'o1', name: 'Outlet Sudirman Tower Lantai Dasar', address: 'Jl. Jenderal Sudirman Kav. 52-53, Senayan, Kebayoran Baru, Jakarta Selatan', openHour: 7, closeHour: 22, deliveryRadiusKm: 1.5, lat: -6.2088, lng: 106.8222, phone: '081355500001');

// Outlet tanpa koordinat dan telepon (server lama): footer harus tetap aman dan hanya menampilkan tombol Rute.
final _outletBare = Outlet(id: 'o2', name: 'Outlet Baru', address: 'Jl. Contoh No. 1', openHour: 8, closeHour: 23, deliveryRadiusKm: 0);

Product _p(String id, String name, int price, [String? cat]) => Product(id: id, name: name, price: price, categoryName: cat, groups: const []);

final _menu = [
  Category(id: 'c1', name: 'Kopi', products: [
    _p('p1', 'Kopi Susu Gula Aren Spesial Edisi Panjang', 22000, 'Kopi'), _p('p2', 'Americano', 18000, 'Kopi'), _p('p3', 'Caramel Macchiato Extra Shot', 28000, 'Kopi'),
    _p('p4', 'Mocha Latte', 27000, 'Kopi'), _p('p5', 'Hazelnut Latte', 27000, 'Kopi'), _p('p6', 'Espresso Single', 15000, 'Kopi'),
  ]),
  Category(id: 'c2', name: 'Makanan', products: [
    _p('p7', 'Chicken Mayo Sandwich Jumbo Dengan Keju', 28000, 'Makanan'), _p('p8', 'Banana Bread', 18000, 'Makanan'), _p('p9', 'Glazed Donut', 12000, 'Makanan'), _p('p10', 'Choco Chip Cookie', 15000, 'Makanan'),
  ]),
];

OrderView _order() => OrderView(
      id: 'x', code: 'KP1', type: 'PICKUP', status: 'COMPLETED', total: 94000, subtotal: 94000, discount: 0, deliveryFee: 0, pointsUsed: 0, createdAt: DateTime(2026, 10, 20),
      outletName: 'Outlet Sudirman Tower Lantai Dasar',
      items: [OrderItemView(name: 'Kopi Susu Gula Aren Spesial Edisi Panjang', qty: 2, unitPrice: 22000, options: const ['Large'], productId: 'p1'), OrderItemView(name: 'Americano', qty: 1, unitPrice: 18000, options: const [])],
    );

final _tiers = [
  Tier(id: 't0', name: 'Member', minSpend: 0, earnMultiplierPct: 100, discountPct: 0),
  Tier(id: 't1', name: 'Silver', minSpend: 500000, earnMultiplierPct: 125, discountPct: 3, maxDiscount: 10000),
  Tier(id: 't2', name: 'Gold Eksklusif Panjang', minSpend: 2000000, earnMultiplierPct: 150, discountPct: 5, maxDiscount: 15000),
  Tier(id: 't3', name: 'Platinum', minSpend: 5000000, earnMultiplierPct: 200, discountPct: 8, maxDiscount: 25000),
];

Membership _membership({int at = 2}) => Membership(
      lifetimeSpend: 2300000,
      current: _tiers[at],
      next: at < 3 ? _tiers[at + 1] : null,
      remainingToNext: at < 3 ? 2700000 : null,
      progressPct: at < 3 ? 9 : 100,
      tiers: _tiers,
    );

CheckInView _checkIn({bool claimed = false}) => CheckInView(
      today: '2026-10-26', claimedToday: claimed, streak: 3, dayInCycle: 4, nextPoints: 1,
      rewards: [for (var d = 1; d <= 7; d++) CheckInDay(day: d, points: d == 7 ? 5 : (d == 3 || d == 6 ? 2 : 1), claimed: d < 4)],
    );

class _FakeAuth extends AuthNotifier {
  @override
  Future<UserProfile?> build() async => UserProfile(id: 'u', phone: '6281299990001', name: 'Muhammad Azmi Zein Panjang Sekali', points: 1250, unread: 6, completionPercent: 40, missing: const ['email', 'birthDate', 'gender']);
}

class _Fav extends Favorites {
  _Fav(this.ids);
  final Set<String> ids;
  @override
  Set<String> build() => ids;
}

final _serverPromos = [
  PromoSlide(title: 'Hemat 10% Pesanan Pertamamu Sekarang Juga', body: 'Pakai kode HEMAT10 untuk diskon 10% (min. belanja Rp30.000, maks Rp15.000).', art: 'product_latte', ctaLabel: 'Pakai voucher HEMAT10 sekarang', voucherCode: 'HEMAT10'),
  PromoSlide(title: 'Diantar ke Pintu', body: 'Pilih ambil di outlet, atau diantar langsung oleh kurir kami.', art: 'seni_tak_dikenal'),
];

class _FixedOutlet extends SelectedOutlet {
  _FixedOutlet(this.o);
  final Outlet o;
  @override
  Outlet? build() => o;
}

class _Tab extends ShellTab {
  _Tab(this.i);
  final int i;
  @override
  int build() => i;
}

class _Cart extends Cart {
  @override
  List<CartLine> build() => [CartLine(product: _menu.first.products.first, options: const [], qty: 2)];
}

void main() {
  setUpAll(() async {
    await _loadRoboto();
    await initializeDateFormatting('id_ID');
  });

  Future<void> render(WidgetTester t, {required int tab, required Size logical, required double fontScale, bool withCart = false, bool highest = false, String? snap, List<PromoSlide> promos = const [], Set<String> favs = const {}, String? tapText, Outlet? outlet}) async {
    t.view.physicalSize = logical * 2.625;
    t.view.devicePixelRatio = 2.625;
    addTearDown(t.view.reset);
    // Diagnostik: bila ada overflow, cetak widget penyebabnya (bukan hanya jumlah piksel).
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('overflowed')) debugPrint(d.toDiagnosticsNode().toStringDeep());
      originalOnError?.call(d);
    };
    addTearDown(() => FlutterError.onError = originalOnError);
    final key = GlobalKey();
    await t.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith(_FakeAuth.new),
        outletsProvider.overrideWith((ref) async => [_outlet]),
        selectedOutletProvider.overrideWith(() => _FixedOutlet(outlet ?? _outlet)),
        shellTabProvider.overrideWith(() => _Tab(tab)),
        welcomePromosProvider.overrideWith((ref) async => promos),
        favoritesProvider.overrideWith(() => _Fav(favs)),
        menuProvider.overrideWith((ref, id) async => _menu),
        ordersProvider.overrideWith((ref) async => [_order()]),
        popularProvider.overrideWith((ref, id) async => ['p1', 'p3', 'p7', 'p2']),
        activeVouchersProvider.overrideWith((ref) async => [VoucherView(code: 'HEMAT10', type: 'PERCENT', value: 10, minSpend: 30000, maxDiscount: 15000, endsAt: DateTime(2027))]),
        membershipProvider.overrideWith((ref) async => _membership(at: highest ? 3 : 2)),
        checkInProvider.overrideWith((ref) async => _checkIn()),
        inboxProvider.overrideWith((ref) async => Inbox(unread: 6, items: [InboxItem(id: 'n1', type: 'ORDER', title: 'Pesanan sedang dibuat', body: 'Pesanan KP1 sedang dibuat oleh barista kami.', read: false, createdAt: DateTime(2026, 10, 25))])),
        pointsHistoryProvider.overrideWith((ref) async => [PointEntry(delta: 4, reason: 'ORDER', at: DateTime(2026, 10, 20)), PointEntry(delta: -7, reason: 'REDEEM', at: DateTime(2026, 10, 21))]),
        if (withCart) cartProvider.overrideWith(_Cart.new),
      ],
      child: RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: buildTheme(),
          debugShowCheckedModeBanner: false,
          // Sama persis dengan app: skala font dibatasi.
          builder: (context, child) => MediaQuery.withClampedTextScaling(minScaleFactor: 0.9, maxScaleFactor: 1.15, child: MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(fontScale)), child: child!)),
          home: const HomeShell(),
        ),
      ),
    ));
    // Cukup lama agar animasi masuk berundak, hitung-naik, dan bilah keranjang selesai sebelum diperiksa/dipotret.
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 150));
    }
    if (tapText != null) {
      await t.tap(find.text(tapText).first);
      for (var i = 0; i < 3; i++) {
        await t.pump(const Duration(milliseconds: 150));
      }
    }
    final err = t.takeException();
    expect(err, isNull, reason: 'tab $tab, layar ${logical.width.toInt()}x${logical.height.toInt()}, font $fontScale -> $err');

    final dir = Platform.environment['SNAP_DIR'];
    if (dir != null && snap != null) {
      await t.runAsync(() async {
        final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await b.toImage(pixelRatio: 1.0);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$dir/$snap.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
    await t.pumpWidget(const SizedBox()); // hentikan timer (banner, polling)
  }

  const phone = Size(411, 914);
  const small = Size(360, 640);
  const names = ['beranda', 'menu', 'member', 'merch', 'saya'];

  for (var tab = 0; tab < 5; tab++) {
    for (final (size, label) in [(phone, 'HP biasa'), (small, 'layar kecil')]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('tab ${names[tab]} • $label • font ${scale}x tanpa overflow', (t) => render(t, tab: tab, logical: size, fontScale: scale, snap: size == phone && scale == 1.0 ? 'tab-${names[tab]}' : null));
      }
    }
  }
  // Banner beranda dari promo admin (ilustrasi tak dikenal harus jatuh ke gambar bawaan), dan favorit di tab Menu.
  testWidgets('beranda • banner promo dari server • layar kecil • font 1.3x tanpa overflow', (t) => render(t, tab: 0, logical: small, fontScale: 1.3, promos: _serverPromos));
  testWidgets('beranda • banner promo dari server • HP biasa', (t) => render(t, tab: 0, logical: phone, fontScale: 1.0, promos: _serverPromos, snap: 'home-promo'));
  testWidgets('menu • favorit terisi • layar kecil • font 1.3x tanpa overflow', (t) => render(t, tab: 1, logical: small, fontScale: 1.3, favs: {'p1', 'p3', 'p7'}, tapText: 'Favorit'));
  testWidgets('menu • favorit kosong menampilkan keadaan kosong', (t) async {
    await render(t, tab: 1, logical: phone, fontScale: 1.0, tapText: 'Favorit', snap: 'menu-fav-empty');
  });
  testWidgets('menu • favorit terisi • HP biasa', (t) => render(t, tab: 1, logical: phone, fontScale: 1.0, favs: {'p1', 'p3'}, tapText: 'Favorit', snap: 'menu-fav'));
  testWidgets('member level tertinggi • layar kecil • font 1.3x tanpa overflow', (t) => render(t, tab: 2, logical: small, fontScale: 1.3, highest: true));
  // Layar sangat tinggi: daftar dibangun malas, jadi tanpa ini bagian di bawah layar tidak pernah diperiksa.
  const tall = Size(411, 5200);
  for (var tab = 0; tab < 5; tab++) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('tab ${names[tab]} • SELURUH halaman (layar tinggi) • font ${scale}x tanpa overflow', (t) => render(t, tab: tab, logical: tall, fontScale: scale, snap: tab == 0 && scale == 1.0 ? 'home-tall' : null));
    }
  }
  // Beranda penuh (termasuk footer) pada layar paling sempit, dan footer untuk outlet tanpa telepon/koordinat.
  const tallNarrow = Size(360, 5200);
  for (final scale in [1.0, 1.3]) {
    testWidgets('beranda • SELURUH halaman • layar sempit 360 • font ${scale}x tanpa overflow', (t) => render(t, tab: 0, logical: tallNarrow, fontScale: scale, snap: scale == 1.0 ? 'home-tall-narrow' : null));
    testWidgets('beranda • SELURUH halaman • outlet tanpa telepon • font ${scale}x tanpa overflow', (t) => render(t, tab: 0, logical: tall, fontScale: scale, outlet: _outletBare));
  }
  testWidgets('beranda dengan bar keranjang • font 1.3x tanpa overflow', (t) => render(t, tab: 0, logical: small, fontScale: 1.3, withCart: true));
}
