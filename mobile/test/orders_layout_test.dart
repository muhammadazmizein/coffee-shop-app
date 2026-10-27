import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopi_app/core/theme.dart';
import 'package:kopi_app/models/models.dart';
import 'package:kopi_app/screens/orders_screen.dart';
import 'package:kopi_app/state/providers.dart';
import 'package:kopi_app/widgets/order_tracker.dart';

/// Menjaga tata letak daftar dan detail pesanan: setiap status dirender dengan nama produk/outlet sangat panjang pada
/// dua ukuran layar dan dua skala font. Flutter melempar error saat ada overflow, jadi test gagal bila ada yang meluap.
/// Bila env SNAP_DIR diisi, beberapa hasil render disimpan sebagai PNG untuk ditinjau.
final _fonts = '${Platform.environment['HOME']}/development/flutter/bin/cache/artifacts/material_fonts';

Future<void> _loadFonts() async {
  final roboto = FontLoader('Roboto');
  for (final f in ['Regular', 'Medium', 'Bold', 'Black']) {
    final file = File('$_fonts/Roboto-$f.ttf');
    if (file.existsSync()) roboto.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await roboto.load();
  final icons = File('$_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await loader.load();
  }
}

const _longOutlet = 'Outlet Sudirman Tower Lantai Dasar Gedung Perkantoran Utama Jakarta Pusat';
const _longName = 'Kopi Susu Gula Aren Spesial Edisi Panjang Dengan Tambahan Sangat Banyak';

List<OrderItemView> _items() => [
      OrderItemView(name: _longName, qty: 2, unitPrice: 31000, options: const ['Large', 'Boba', 'Extra Shot', 'Less Sugar'], productId: 'p1', note: 'es sedikit dan tolong dipisah gulanya ya kak'),
      OrderItemView(name: 'Chicken Mayo Sandwich Jumbo Dengan Keju Leleh', qty: 1, unitPrice: 28000, options: const [], productId: 'p2'),
      OrderItemView(name: 'Croissant Butter', qty: 3, unitPrice: 20000, options: const [], productId: 'p3'),
    ];

PaymentView _payment({bool pending = true}) => PaymentView(
      orderId: 'x', method: 'bca_va', group: 'va', status: pending ? 'PENDING' : 'EXPIRED', amount: 148000,
      expiresAt: DateTime.now().add(const Duration(minutes: 20)), vaBank: 'bca', vaNumber: '95138997431707484711522',
    );

OrderView _order(String status, {String type = 'PICKUP', String? id, bool courier = false, bool member = true}) {
  final reached = <String>[
    if (status != 'PENDING_PAYMENT' && status != 'EXPIRED') 'PAID',
    if (const {'PREPARING', 'READY', 'ON_DELIVERY', 'COMPLETED'}.contains(status)) 'PREPARING',
    if (const {'READY', 'ON_DELIVERY', 'COMPLETED'}.contains(status)) 'READY',
    if (const {'ON_DELIVERY', 'COMPLETED'}.contains(status) && type == 'DELIVERY') 'ON_DELIVERY',
    if (status == 'COMPLETED') 'COMPLETED',
    if (status == 'CANCELLED' || status == 'EXPIRED') status,
  ];
  return OrderView(
    id: id ?? 'o-$status-$type', code: 'KPMVKMVP365846', type: type, status: status, total: 148000, subtotal: 150000, discount: 5000, deliveryFee: type == 'DELIVERY' ? 8000 : 0,
    pointsUsed: 10, memberDiscount: member ? 7500 : 0, tierName: member ? 'Gold Eksklusif Panjang' : null, createdAt: DateTime(2026, 10, 25, 14, 20), outletName: _longOutlet,
    items: _items(), courierName: courier ? 'Pak Joko Sangat Panjang Namanya' : null, courierPhone: courier ? '6281355500001' : null,
    payment: status == 'PENDING_PAYMENT' ? _payment() : null,
    events: [for (final s in ['PENDING_PAYMENT', ...reached]) OrderEventView(status: s, at: DateTime(2026, 10, 25, 14, 20))],
  );
}

final _mixed = [
  _order('PENDING_PAYMENT', id: 'a1'), _order('PAID', id: 'a2'), _order('PREPARING', id: 'a3'), _order('READY', id: 'a4', type: 'DELIVERY'),
  _order('ON_DELIVERY', id: 'a5', type: 'DELIVERY', courier: true), _order('COMPLETED', id: 'h1'), _order('CANCELLED', id: 'h2'), _order('EXPIRED', id: 'h3'),
];

Future<void> _pump(WidgetTester t, Widget home, {required Size logical, required double fontScale, List<Override> overrides = const [], String? snap}) async {
  t.view.physicalSize = logical * 2.625;
  t.view.devicePixelRatio = 2.625;
  addTearDown(t.view.reset);
  // Diagnostik: bila ada overflow, cetak widget penyebabnya (bukan hanya jumlah piksel).
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
        // Sama dengan app: skala font dibatasi.
        builder: (context, child) => MediaQuery.withClampedTextScaling(minScaleFactor: 0.9, maxScaleFactor: 1.15, child: MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(fontScale)), child: child!)),
        home: home,
      ),
    ),
  ));
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
  final err = t.takeException();
  expect(err, isNull, reason: '${logical.width.toInt()}x${logical.height.toInt()}, font $fontScale -> $err');

  final dir = Platform.environment['SNAP_DIR'];
  if (dir != null && snap != null) {
    await t.runAsync(() async {
      final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await b.toImage(pixelRatio: 1.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$dir/$snap.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }
}

Future<void> _dispose(WidgetTester t) async => t.pumpWidget(const SizedBox()); // hentikan timer (polling, denyut, skeleton)

void main() {
  setUpAll(() async {
    await _loadFonts();
    await initializeDateFormatting('id_ID');
  });

  const phone = Size(411, 914);
  const small = Size(360, 640);
  final sizes = [(phone, 'HP biasa'), (small, 'layar kecil')];
  const scales = [1.0, 1.3];

  group('daftar pesanan', () {
    for (final (size, label) in sizes) {
      for (final scale in scales) {
        final tag = '$label • font ${scale}x';

        testWidgets('campuran semua status, tab Aktif • $tag', (t) async {
          await _pump(t, const OrdersTab(), logical: size, fontScale: scale, overrides: [ordersProvider.overrideWith((ref) async => _mixed)], snap: size == phone && scale == 1.0 ? 'orders-aktif' : null);
          await _dispose(t);
        });

        testWidgets('campuran semua status, tab Riwayat • $tag', (t) async {
          await _pump(t, const OrdersTab(), logical: size, fontScale: scale, overrides: [ordersProvider.overrideWith((ref) async => _mixed)]);
          await t.tap(find.text('Riwayat'));
          await t.pump(const Duration(milliseconds: 400));
          await t.pump(const Duration(milliseconds: 400));
          expect(t.takeException(), isNull);
          await _dispose(t);
        });

        testWidgets('kosong • $tag', (t) async {
          await _pump(t, const OrdersTab(), logical: size, fontScale: scale, overrides: [ordersProvider.overrideWith((ref) async => <OrderView>[])], snap: size == phone && scale == 1.0 ? 'orders-kosong' : null);
          await t.tap(find.text('Riwayat'));
          await t.pump(const Duration(milliseconds: 400));
          await t.pump(const Duration(milliseconds: 400));
          expect(t.takeException(), isNull);
          await _dispose(t);
        });

        testWidgets('memuat (skeleton) • $tag', (t) async {
          await _pump(t, const OrdersTab(), logical: size, fontScale: scale, overrides: [ordersProvider.overrideWith((ref) => Completer<List<OrderView>>().future)], snap: size == phone && scale == 1.0 ? 'orders-memuat' : null);
          await _dispose(t);
        });

        testWidgets('gagal memuat • $tag', (t) async {
          await _pump(t, const OrdersTab(), logical: size, fontScale: scale, overrides: [ordersProvider.overrideWith((ref) async => throw Exception('Tidak dapat terhubung ke server'))]);
          expect(find.text('Coba lagi'), findsOneWidget);
          await _dispose(t);
        });
      }
    }
  });

  group('detail pesanan', () {
    final cases = <(String, OrderView)>[
      ('PENDING_PAYMENT', _order('PENDING_PAYMENT')),
      ('PAID', _order('PAID')),
      ('PREPARING', _order('PREPARING')),
      ('READY pickup', _order('READY')),
      ('READY delivery', _order('READY', type: 'DELIVERY')),
      ('ON_DELIVERY + kurir', _order('ON_DELIVERY', type: 'DELIVERY', courier: true)),
      ('COMPLETED', _order('COMPLETED')),
      ('CANCELLED', _order('CANCELLED')),
      ('EXPIRED', _order('EXPIRED')),
      ('COMPLETED tanpa diskon member', _order('COMPLETED', member: false)),
    ];
    for (final (name, order) in cases) {
      for (final (size, label) in sizes) {
        for (final scale in scales) {
          testWidgets('$name • $label • font ${scale}x', (t) async {
            final snap = size == phone && scale == 1.0 ? 'detail-${name.replaceAll(RegExp(r'[^A-Za-z_]+'), '-')}' : null;
            await _pump(t, OrderDetailScreen(id: order.id), logical: size, fontScale: scale, overrides: [orderProvider.overrideWith((ref, id) async => order)], snap: snap);
            await _dispose(t);
          });
        }
      }
    }

    testWidgets('memuat (skeleton) dan gagal memuat', (t) async {
      await _pump(t, const OrderDetailScreen(id: 'x'), logical: phone, fontScale: 1.0, overrides: [orderProvider.overrideWith((ref, id) => Completer<OrderView>().future)]);
      await _dispose(t);
      await _pump(t, const OrderDetailScreen(id: 'x'), logical: phone, fontScale: 1.0, overrides: [orderProvider.overrideWith((ref, id) async => throw Exception('gagal'))]);
      expect(find.text('Coba lagi'), findsOneWidget);
      await _dispose(t);
    });
  });

  group('pelacak langkah', () {
    test('tonggak per status', () {
      expect(milestoneOf('PENDING_PAYMENT', 'PICKUP'), -1);
      expect(milestoneOf('PAID', 'PICKUP'), 0);
      expect(milestoneOf('PREPARING', 'DELIVERY'), 1);
      expect(milestoneOf('READY', 'PICKUP'), 2);
      expect(milestoneOf('READY', 'DELIVERY'), 1); // siap dikirim tapi belum berangkat
      expect(milestoneOf('ON_DELIVERY', 'DELIVERY'), 2);
      expect(milestoneOf('COMPLETED', 'PICKUP'), 3);
      expect(milestoneOf('CANCELLED', 'PICKUP'), -1);
    });

    test('label langkah ketiga mengikuti jenis pesanan', () {
      expect(trackerLabels('PICKUP')[2], 'Siap diambil');
      expect(trackerLabels('DELIVERY')[2], 'Diantar');
    });

    testWidgets('pesanan batal menampilkan label "Dibatalkan", kedaluwarsa menampilkan "Kedaluwarsa"', (t) async {
      await t.pumpWidget(const MaterialApp(home: Scaffold(body: OrderTracker(status: 'CANCELLED', type: 'PICKUP', eventStatuses: ['PENDING_PAYMENT', 'PAID']))));
      expect(find.text('Dibatalkan'), findsOneWidget);
      await t.pumpWidget(const MaterialApp(home: Scaffold(body: OrderTracker(status: 'EXPIRED', type: 'PICKUP', eventStatuses: ['PENDING_PAYMENT']))));
      expect(find.text('Kedaluwarsa'), findsOneWidget);
      await _dispose(t);
    });
  });
}
