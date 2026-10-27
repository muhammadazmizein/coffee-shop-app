import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopi_app/core/theme.dart';
import 'package:kopi_app/models/models.dart';
import 'package:kopi_app/screens/login_screen.dart';
import 'package:kopi_app/state/providers.dart';

/// Tata letak layar login pada langkah nomor dan langkah OTP (HP biasa, layar kecil, font diperbesar).
/// Bila env SNAP_DIR diisi, hasil disimpan sebagai PNG.
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

class _Auth extends AuthNotifier {
  @override
  Future<UserProfile?> build() async => null;

  @override
  Future<String?> requestOtp(String phone) async => '812359';
}

void main() {
  setUpAll(_loadFonts);

  Future<void> render(WidgetTester t, {required Size logical, required double fontScale, required bool otp, String? snap}) async {
    t.view.physicalSize = logical * 2.625;
    t.view.devicePixelRatio = 2.625;
    addTearDown(t.view.reset);
    final key = GlobalKey();
    // Diagnostik: bila ada overflow, cetak widget penyebabnya (bukan hanya jumlah piksel).
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('overflowed')) debugPrint(d.toDiagnosticsNode().toStringDeep());
      originalOnError?.call(d);
    };
    addTearDown(() => FlutterError.onError = originalOnError);
    await t.pumpWidget(ProviderScope(
      overrides: [authProvider.overrideWith(_Auth.new)],
      child: RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: buildTheme(),
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery.withClampedTextScaling(minScaleFactor: 0.9, maxScaleFactor: 1.15, child: MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(fontScale)), child: child!)),
          home: const LoginScreen(),
        ),
      ),
    ));
    await t.pump();
    if (otp) {
      await t.enterText(find.byType(TextField).first, '0812-9999-0001');
      await t.pump();
      await t.tap(find.text('Kirim kode OTP'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(t.takeException(), isNull, reason: 'login otp=$otp ${logical.width.toInt()}x${logical.height.toInt()} font $fontScale');

    final dir = Platform.environment['SNAP_DIR'];
    if (dir != null && snap != null) {
      await t.runAsync(() async {
        final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await b.toImage(pixelRatio: 1.0);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$dir/$snap.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
    await t.pumpWidget(const SizedBox()); // hentikan timer hitung mundur
  }

  for (final (size, label) in [(const Size(411, 914), 'HP biasa'), (const Size(360, 640), 'layar kecil')]) {
    for (final scale in [1.0, 1.3]) {
      for (final otp in [false, true]) {
        testWidgets('login • ${otp ? 'langkah OTP' : 'langkah nomor'} • $label • font ${scale}x tanpa overflow',
            (t) => render(t, logical: size, fontScale: scale, otp: otp, snap: size.width == 411 && scale == 1.0 ? (otp ? 'login-otp' : 'login-phone') : null));
      }
    }
  }
}
