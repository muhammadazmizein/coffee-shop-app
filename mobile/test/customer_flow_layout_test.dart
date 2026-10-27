import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kopi_app/core/api.dart';
import 'package:kopi_app/core/theme.dart';
import 'package:kopi_app/models/models.dart';
import 'package:kopi_app/screens/cart_screen.dart';
import 'package:kopi_app/screens/checkout_screen.dart';
import 'package:kopi_app/screens/product_screen.dart';
import 'package:kopi_app/state/providers.dart';

/// Alur belanja pelanggan (detail produk, keranjang, checkout) dirender pada beberapa ukuran layar dan skala font
/// dengan data sengaja panjang. Flutter melempar error saat ada overflow, jadi test ini gagal bila ada yang meluap.
/// Bila env SNAP_DIR diisi, hasilnya disimpan sebagai PNG.
final _fonts = '${Platform.environment['HOME']}/development/flutter/bin/cache/artifacts/material_fonts';

Future<void> _loadFonts() async {
  final r = FontLoader('Roboto');
  for (final f in ['Regular', 'Medium', 'Bold', 'Black']) {
    final file = File('$_fonts/Roboto-$f.ttf');
    if (file.existsSync()) r.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await r.load();
  final icons = File('$_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final i = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await i.load();
  }
}

Product _product({bool longName = true}) => Product(
      id: 'p1',
      name: longName ? 'Kopi Susu Gula Aren Spesial Edisi Terbatas Dengan Nama Yang Sangat Panjang Sekali' : 'Kopi Susu Gula Aren',
      price: 22000,
      description: 'Espresso, susu segar, dan gula aren pilihan yang dibuat dengan penuh perhatian oleh barista kami setiap hari.',
      categoryName: 'Kopi',
      groups: [
        OptionGroup(id: 'g1', name: 'Ukuran', required: true, maxSelect: 1, options: [Option(id: 'a', name: 'Regular', extraPrice: 0), Option(id: 'b', name: 'Large', extraPrice: 4000)]),
        OptionGroup(id: 'g2', name: 'Tingkat Gula', required: true, maxSelect: 1, options: [
          Option(id: 'c', name: 'Normal', extraPrice: 0),
          Option(id: 'd', name: 'Kurang Manis', extraPrice: 0),
          Option(id: 'e', name: 'Tanpa Gula Sama Sekali', extraPrice: 0),
        ]),
        OptionGroup(id: 'g3', name: 'Topping', required: false, maxSelect: 2, options: [
          Option(id: 'f', name: 'Extra Shot Espresso', extraPrice: 5000),
          Option(id: 'h', name: 'Boba', extraPrice: 5000),
          Option(id: 'i', name: 'Jelly Leci', extraPrice: 3000),
        ]),
      ],
    );

class _Cart extends Cart {
  @override
  List<CartLine> build() {
    final p = _product();
    return [
      CartLine(product: p, options: [p.groups[0].options[1], p.groups[1].options[2], p.groups[2].options[0]], qty: 2, note: 'es sedikit dan tolong dipisah sedotannya ya'),
      CartLine(product: Product(id: 'p2', name: 'Croissant Butter', price: 20000, categoryName: 'Makanan', groups: const []), options: const [], qty: 1),
      CartLine(product: Product(id: 'p3', name: 'Chicken Mayo Sandwich Jumbo Dengan Keju', price: 28000, categoryName: 'Makanan', groups: const []), options: const [], qty: 3),
    ];
  }
}

class _EmptyCart extends Cart {
  @override
  List<CartLine> build() => [];
}

final _outlet = Outlet(id: 'o1', name: 'Outlet Sudirman Tower Lantai Dasar', address: 'Jl. Sudirman', openHour: 7, closeHour: 22, deliveryRadiusKm: 1.5);

class _Outlet extends SelectedOutlet {
  _Outlet(this.o);
  final Outlet o;
  @override
  Outlet? build() => o;
}

class _Auth extends AuthNotifier {
  @override
  Future<UserProfile?> build() async => UserProfile(id: 'u', phone: '6281299990001', name: 'Azmi', points: 1250);
}

/// Api palsu: quote langsung terjawab, atau tak pernah selesai (untuk memeriksa tampilan skeleton).
class _FakeApi extends Api {
  _FakeApi({this.hang = false}) : super(onUnauthorized: () {});
  final bool hang;

  @override
  Future<T> post<T>(String path, Object? body, T Function(dynamic) parse, {bool auth = false}) {
    if (hang) return Completer<T>().future;
    return Future.value(parse({'subtotal': 132000, 'discount': 4000, 'pointsUsed': 40, 'pointDiscount': 4000, 'deliveryFee': 8000, 'total': 124400, 'memberDiscount': 7600, 'tierName': 'Silver', 'pointsToEarn': 12}));
  }
}

final _addresses = [
  Address(id: 'a1', label: 'Rumah', recipient: 'Muhammad Azmi Zein', detail: 'Jl. Contoh Raya No. 12, RT 03/RW 04, Kelurahan Setiabudi, Kecamatan Setiabudi, Jakarta Selatan'),
  Address(id: 'a2', label: 'Kantor', recipient: 'Azmi', detail: 'Gedung Tinggi Lt. 9'),
];

final _vouchers = [
  VoucherView(code: 'HEMAT10', type: 'PERCENT', value: 10, minSpend: 30000, maxDiscount: 15000, endsAt: DateTime(2027)),
  VoucherView(code: 'KOPIGRATIS', type: 'FIXED', value: 5000, minSpend: 0, endsAt: DateTime(2027)),
];

/// Animasi baru mulai pada frame pertama, jadi perlu dua pump agar benar-benar selesai.
Future<void> _settle(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 50));
  await t.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(_loadFonts);

  Future<void> render(WidgetTester t, String name, Widget home, {required Size logical, required double font, List<Override> overrides = const [], bool snap = false, Future<void> Function(WidgetTester)? after}) async {
    t.view.physicalSize = logical * 2.625;
    t.view.devicePixelRatio = 2.625;
    addTearDown(t.view.reset);
    final original = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('overflowed')) debugPrint(d.toDiagnosticsNode().toStringDeep());
      original?.call(d);
    };
    addTearDown(() => FlutterError.onError = original);
    final key = GlobalKey();
    await t.pumpWidget(ProviderScope(
      overrides: overrides,
      child: RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: buildTheme(),
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery.withClampedTextScaling(minScaleFactor: 0.9, maxScaleFactor: 1.15, child: MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(font)), child: child!)),
          home: home,
        ),
      ),
    ));
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
    if (after != null) {
      await after(t);
      for (var i = 0; i < 3; i++) {
        await t.pump(const Duration(milliseconds: 200));
      }
    }
    final err = t.takeException();
    expect(err, isNull, reason: '$name ${logical.width.toInt()}x${logical.height.toInt()} font $font -> $err');

    final dir = Platform.environment['SNAP_DIR'];
    if (dir != null && snap) {
      await t.runAsync(() async {
        final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await b.toImage(pixelRatio: 1.0);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
    await t.pumpWidget(const SizedBox());
  }

  const phone = Size(411, 914);
  const small = Size(360, 640);

  List<Override> checkout({bool hang = false, bool withAddresses = true, Outlet? outlet}) => [
        cartProvider.overrideWith(_Cart.new),
        selectedOutletProvider.overrideWith(() => _Outlet(outlet ?? _outlet)),
        apiProvider.overrideWith((ref) => _FakeApi(hang: hang)),
        addressesProvider.overrideWith((ref) async => withAddresses ? _addresses : <Address>[]),
        activeVouchersProvider.overrideWith((ref) async => _vouchers),
        authProvider.overrideWith(_Auth.new),
      ];

  for (final (size, label) in [(phone, 'HP biasa'), (small, 'layar kecil')]) {
    for (final font in [1.0, 1.3]) {
      final snap = size == phone && font == 1.0;
      final tag = '$label • font ${font}x';

      testWidgets('detail produk (nama sangat panjang) • $tag', (t) => render(t, 'produk', ProductScreen(product: _product()), logical: size, font: font, snap: snap, overrides: [cartProvider.overrideWith(_Cart.new)]));
      testWidgets('detail produk setelah melewati batas topping • $tag', (t) => render(t, 'produk-batas', ProductScreen(product: _product(longName: false)), logical: size, font: font, snap: snap, after: (t) async {
            for (final n in ['Extra Shot Espresso', 'Boba', 'Jelly Leci']) {
              await t.scrollUntilVisible(find.text(n), 120, scrollable: find.byType(Scrollable).first);
              await t.ensureVisible(find.text(n));
              await t.pump();
              await t.tap(find.text(n));
              await t.pump();
            }
          }));
      testWidgets('keranjang berisi • $tag', (t) => render(t, 'keranjang', const CartScreen(), logical: size, font: font, snap: snap, overrides: [cartProvider.overrideWith(_Cart.new), selectedOutletProvider.overrideWith(() => _Outlet(_outlet))]));
      testWidgets('keranjang kosong • $tag', (t) => render(t, 'keranjang-kosong', const CartScreen(), logical: size, font: font, snap: snap, overrides: [cartProvider.overrideWith(_EmptyCart.new)]));
      testWidgets('checkout pickup • $tag', (t) => render(t, 'checkout-pickup', const CheckoutScreen(), logical: size, font: font, snap: snap, overrides: checkout()));
      testWidgets('checkout skeleton (quote dimuat) • $tag', (t) => render(t, 'checkout-skeleton', const CheckoutScreen(), logical: size, font: font, snap: snap, overrides: checkout(hang: true)));
      testWidgets('checkout delivery dengan alamat • $tag', (t) => render(t, 'checkout-delivery', const CheckoutScreen(), logical: size, font: font, snap: snap, overrides: checkout(), after: (t) async {
            await t.tap(find.text('Diantar'));
            await _settle(t);
            // Konten memendek setelah memilih Diantar, jadi gulir balik ke atas sampai alamat terbangun.
            await t.scrollUntilVisible(find.textContaining('Rumah'), -200, scrollable: find.byType(Scrollable).first, maxScrolls: 40);
            await t.ensureVisible(find.textContaining('Rumah'));
            await t.tap(find.textContaining('Rumah'));
            await _settle(t);
          }));
      testWidgets('checkout delivery tanpa alamat • $tag', (t) => render(t, 'checkout-delivery-kosong', const CheckoutScreen(), logical: size, font: font, snap: snap, overrides: checkout(withAddresses: false), after: (t) async {
            await t.tap(find.text('Diantar'));
            await _settle(t);
          }));
    }
  }

  // Layar sangat tinggi hanya untuk memotret seluruh isi checkout (bagian bawah biasanya di luar layar).
  const tall = Size(411, 1750);
  testWidgets('checkout tinggi • pickup', (t) => render(t, 'tall-pickup', const CheckoutScreen(), logical: tall, font: 1.0, snap: true, overrides: checkout()));
  testWidgets('checkout tinggi • skeleton', (t) => render(t, 'tall-skeleton', const CheckoutScreen(), logical: tall, font: 1.0, snap: true, overrides: checkout(hang: true)));
  testWidgets('checkout tinggi • delivery dengan alamat dan voucher', (t) => render(t, 'tall-delivery', const CheckoutScreen(), logical: tall, font: 1.0, snap: true, overrides: checkout(), after: (t) async {
        await t.tap(find.text('Diantar'));
        await _settle(t);
        await t.tap(find.textContaining('Rumah'));
        await _settle(t);
        expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget, reason: 'alamat Rumah harus terpilih');
        expect(find.text('Ongkos kirim'), findsOneWidget, reason: 'rincian harus memuat ongkir setelah alamat dipilih');
        await t.tap(find.textContaining('HEMAT10 •'));
        await _settle(t);
        await t.tap(find.byType(Switch));
        await _settle(t);
      }));

  testWidgets('checkout: delivery dimatikan bila outlet tanpa radius', (t) => render(t, 'checkout-nodelivery', const CheckoutScreen(), logical: phone, font: 1.0, overrides: checkout(outlet: Outlet(id: 'o', name: 'X', address: 'Y', openHour: 7, closeHour: 22, deliveryRadiusKm: 0))));
}
