import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopi_app/core/format.dart';
import 'package:kopi_app/models/models.dart';
import 'package:kopi_app/screens/product_screen.dart';
import 'package:kopi_app/state/providers.dart';

Product _coffee() => Product(
      id: 'p1',
      name: 'Kopi Susu',
      price: 22000,
      groups: [
        OptionGroup(id: 'g1', name: 'Ukuran', required: true, maxSelect: 1, options: [
          Option(id: 'reg', name: 'Regular', extraPrice: 0),
          Option(id: 'lg', name: 'Large', extraPrice: 4000),
        ]),
        OptionGroup(id: 'g2', name: 'Topping', required: false, maxSelect: 2, options: [
          Option(id: 'boba', name: 'Boba', extraPrice: 5000),
          Option(id: 'shot', name: 'Extra Shot', extraPrice: 5000),
          Option(id: 'jelly', name: 'Jelly', extraPrice: 3000),
        ]),
      ],
    );

void main() {
  orderParsingTests();
  test('rupiah memakai format Indonesia', () {
    expect(rupiah(63800).replaceAll(RegExp(r'\s'), ''), 'Rp63.800');
  });

  group('Cart', () {
    late ProviderContainer c;
    setUp(() => c = ProviderContainer());
    tearDown(() => c.dispose());

    test('harga satuan = harga produk + tambahan opsi', () {
      final p = _coffee();
      final line = CartLine(product: p, options: [p.groups[0].options[1], p.groups[1].options[0]], qty: 2);
      expect(line.unitPrice, 31000);
      expect(line.total, 62000);
    });

    test('baris identik digabung, opsi berbeda dipisah', () {
      final p = _coffee();
      final cart = c.read(cartProvider.notifier);
      cart.add(CartLine(product: p, options: [p.groups[0].options[0]], qty: 1));
      cart.add(CartLine(product: p, options: [p.groups[0].options[0]], qty: 2));
      cart.add(CartLine(product: p, options: [p.groups[0].options[1]], qty: 1));
      expect(c.read(cartProvider).length, 2);
      expect(c.read(cartCountProvider), 4);
    });

    test('qty 0 menghapus baris', () {
      final p = _coffee();
      c.read(cartProvider.notifier).add(CartLine(product: p, options: [], qty: 1));
      c.read(cartProvider.notifier).setQty(0, 0);
      expect(c.read(cartProvider), isEmpty);
    });
  });

  group('ProductScreen', () {
    Future<void> pump(WidgetTester t) => t.pumpWidget(
          ProviderScope(child: MaterialApp(home: ProductScreen(product: _coffee()))),
        );

    testWidgets('grup wajib terpilih default, total mengikuti pilihan', (t) async {
      await pump(t);
      expect(find.textContaining('Tambah'), findsOneWidget);
      await t.tap(find.text('Large'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600)); // angka pada tombol berhitung dulu
      expect(find.textContaining('26.000'), findsOneWidget);
    });

    testWidgets('topping dibatasi maxSelect', (t) async {
      await pump(t);
      for (final n in ['Boba', 'Extra Shot', 'Jelly']) {
        // ListView membangun item secara malas; gulir sampai item benar-benar ada.
        await t.scrollUntilVisible(find.text(n), 100, scrollable: find.byType(Scrollable).first);
        // Pastikan chip benar-benar berada di dalam layar (bukan di balik bilah bawah) sebelum diketuk.
        await t.ensureVisible(find.text(n));
        await t.pump();
        await t.tap(find.text(n));
        await t.pump();
      }
      // 22.000 + 5.000 + 5.000; Jelly ditolak karena maks 2
      await t.pump(const Duration(milliseconds: 600));
      expect(find.textContaining('32.000'), findsOneWidget);
    });
  });
}

void orderParsingTests() {
  group('Parsing dari API', () {
    test('Outlet: radius Decimal berupa string dibaca sebagai angka', () {
      final o = Outlet.fromJson({'id': 'o', 'name': 'N', 'address': 'A', 'openHour': 7, 'closeHour': 22, 'deliveryRadiusKm': '1.5'});
      expect(o.deliveryRadiusKm, 1.5);
      final off = Outlet.fromJson({'id': 'o', 'name': 'N', 'address': 'A', 'openHour': 7, 'closeHour': 22, 'deliveryRadiusKm': '0'});
      expect(off.deliveryRadiusKm, 0);
    });

    test('OrderView: kurir dan riwayat status terbaca', () {
      final o = OrderView.fromJson({
        'id': 'x', 'code': 'KP1', 'type': 'DELIVERY', 'status': 'ON_DELIVERY', 'total': 34000, 'subtotal': 26000,
        'discount': 0, 'deliveryFee': 8000, 'createdAt': '2026-10-23T05:00:00.000Z',
        'courier': {'name': 'Pak Joko', 'phone': '6281355500001'},
        'events': [
          {'status': 'PAID', 'createdAt': '2026-10-23T05:01:00.000Z', 'note': null},
          {'status': 'ON_DELIVERY', 'createdAt': '2026-10-23T05:20:00.000Z', 'note': 'Kurir: Pak Joko'},
        ],
      });
      expect(o.courierName, 'Pak Joko');
      expect(o.events.map((e) => e.status), ['PAID', 'ON_DELIVERY']);
      expect(statusLabel('ON_DELIVERY', 'DELIVERY'), 'Dalam pengiriman');
    });

    test('OrderView tanpa kurir/riwayat (daftar pesanan) tetap valid', () {
      final o = OrderView.fromJson({
        'id': 'x', 'code': 'KP1', 'type': 'PICKUP', 'status': 'PAID', 'total': 1000, 'subtotal': 1000,
        'discount': 0, 'deliveryFee': 0, 'createdAt': '2026-10-23T05:00:00.000Z', 'items': [],
      });
      expect(o.courierName, isNull);
      expect(o.events, isEmpty);
    });
  });
}
