import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopi_app/core/theme.dart';
import 'package:kopi_app/models/models.dart';
import 'package:kopi_app/screens/pay_screen.dart';
import 'package:kopi_app/state/providers.dart';

/// Merender halaman bayar pada ukuran layar HP. Selain menjaga tata letak (Flutter melempar error bila ada overflow),
/// bila env SNAP_DIR diisi, hasilnya disimpan sebagai PNG untuk ditinjau mata.
final _fonts = '${Platform.environment['HOME']}/development/flutter/bin/cache/artifacts/material_fonts';

Future<void> _loadRoboto() async {
  final loader = FontLoader('Roboto');
  for (final f in ['Regular', 'Medium', 'Bold', 'Black']) {
    final file = File('$_fonts/Roboto-$f.ttf');
    if (file.existsSync()) loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await loader.load();
}

OrderView _order(PaymentView? p) => OrderView(
      id: 'o1', code: 'KPMVKMVP365846', type: 'PICKUP', status: 'PENDING_PAYMENT', total: 22000, subtotal: 22000,
      discount: 0, deliveryFee: 0, pointsUsed: 0, createdAt: DateTime.now(), items: const [], payment: p,
    );

PaymentView _pay(String method, {String? va, String? bank, String? qr, String? deeplink, String? biller, String? key, String? ovo}) => PaymentView(
      orderId: 'o1', method: method, group: PaymentView.groupOf(method), status: 'PENDING', amount: 22000,
      expiresAt: DateTime.now().add(const Duration(minutes: 29, seconds: 46)),
      qrString: qr, deeplinkUrl: deeplink, vaBank: bank, vaNumber: va, billerCode: biller, billKey: key, ovoPhone: ovo,
    );

final _methods = [
  PayMethod(key: 'qris', label: 'QRIS', group: 'qris'),
  PayMethod(key: 'gopay', label: 'GoPay', group: 'ewallet'),
  PayMethod(key: 'shopeepay', label: 'ShopeePay', group: 'ewallet'),
  PayMethod(key: 'ovo', label: 'OVO', group: 'ewallet'),
  PayMethod(key: 'bca_va', label: 'BCA Virtual Account', group: 'va'),
  PayMethod(key: 'mandiri_va', label: 'Mandiri Virtual Account', group: 'va'),
];

void main() {
  setUpAll(_loadRoboto);

  Future<void> render(WidgetTester t, String name, PaymentView? payment) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.625;
    addTearDown(t.view.reset);
    final key = GlobalKey();
    await t.pumpWidget(ProviderScope(
      overrides: [
        orderProvider.overrideWith((ref, id) async => _order(payment)),
        payMethodsProvider.overrideWith((ref) async => _methods),
      ],
      child: RepaintBoundary(key: key, child: MaterialApp(theme: buildTheme(), home: const PayScreen(orderId: 'o1'))),
    ));
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 100));
    expect(tester(t), isNull, reason: 'tidak boleh ada exception/overflow');

    final dir = Platform.environment['SNAP_DIR'];
    if (dir != null) {
      await t.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.0);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
    await t.pumpWidget(const SizedBox()); // hentikan timer layar
  }

  testWidgets('BCA VA', (t) => render(t, 'pay-bca', _pay('bca_va', bank: 'bca', va: '95138997431707484711522')));
  testWidgets('QRIS', (t) => render(t, 'pay-qris', _pay('qris', qr: '00020101021226620014ID.CO.QRIS.WWW0118936009150000000000214230012345678901520449995303360540522000.005802ID5911KOPI APP6007JAKARTA6304ABCD')));
  testWidgets('Mandiri', (t) => render(t, 'pay-mandiri', _pay('mandiri_va', biller: '70012', key: '123456789012')));
  testWidgets('OVO', (t) => render(t, 'pay-ovo', _pay('ovo', ovo: '0812 9999 0001')));
  testWidgets('Pilih metode', (t) => render(t, 'pay-chooser', null));
}

Object? tester(WidgetTester t) => t.takeException();
