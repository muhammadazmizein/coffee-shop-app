import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopi_app/models/models.dart';
import 'package:kopi_app/screens/login_screen.dart';
import 'package:kopi_app/state/providers.dart';
import 'package:kopi_app/widgets/otp_boxes.dart';

/// Mode dev: server mengembalikan `devCode`; layar login harus mengisi kotak OTP otomatis.
class _Auth extends AuthNotifier {
  _Auth(this.devCodes);
  final List<String?> devCodes; // dikembalikan berurutan tiap requestOtp
  final List<String> sentTo = [];

  @override
  Future<UserProfile?> build() async => null;

  @override
  Future<String?> requestOtp(String phone) async {
    sentTo.add(phone);
    final i = sentTo.length - 1;
    return devCodes[i < devCodes.length ? i : devCodes.length - 1];
  }
}

Future<_Auth> _pumpLogin(WidgetTester t, List<String?> devCodes) async {
  // Ukuran layar HP: jendela test bawaan (800x600) terlalu pendek sehingga tombol di bawah tidak terjangkau ketukan.
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 2.625;
  addTearDown(t.view.reset);
  final fake = _Auth(devCodes);
  await t.pumpWidget(ProviderScope(overrides: [authProvider.overrideWith(() => fake)], child: const MaterialApp(home: LoginScreen())));
  await t.pump();
  return fake;
}

String _otp(WidgetTester t) => t.widget<TextField>(find.byType(TextField).last).controller!.text;

Future<void> _send(WidgetTester t, String phone) async {
  await t.enterText(find.byType(TextField).first, phone);
  await t.pump();
  await t.tap(find.text('Kirim kode OTP'));
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
}

void main() {
  group('Fungsi murni hitung mundur', () {
    test('formatCountdown', () {
      expect(formatCountdown(30), '0:30');
      expect(formatCountdown(9), '0:09');
      expect(formatCountdown(75), '1:15');
      expect(formatCountdown(-3), '0:00');
    });
    test('resendLabel memuat hitung mundur sampai nol', () {
      expect(resendLabel(30), 'Kirim ulang kode (0:30)');
      expect(resendLabel(1), 'Kirim ulang kode (0:01)');
      expect(resendLabel(0), 'Kirim ulang kode');
    });
  });

  testWidgets('mode dev: kotak OTP terisi otomatis setelah kirim OTP', (t) async {
    final fake = await _pumpLogin(t, ['812359']);
    await _send(t, '0812-9999-0001');

    expect(fake.sentTo.single, '+6281299990001'); // 0 di depan dibuang, awalan +62 dipasang
    expect(_otp(t), '812359');
    expect(find.textContaining('Mode dev'), findsOneWidget);
    // 6 digit tampil di kotak-kotak.
    for (final d in '812359'.split('')) {
      expect(find.text(d), findsWidgets);
    }
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('SMS asli (tanpa devCode): kotak OTP tetap kosong untuk diketik pengguna', (t) async {
    await _pumpLogin(t, [null]);
    await _send(t, '81299990001');

    expect(_otp(t), isEmpty);
    expect(find.textContaining('Mode dev'), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('tombol Masuk baru aktif setelah 6 digit; hanya angka dan maks 6 yang diterima', (t) async {
    await _pumpLogin(t, [null]);
    await _send(t, '81299990001');

    FilledButton button() => t.widget<FilledButton>(find.byType(FilledButton));
    expect(button().onPressed, isNull);

    await t.enterText(find.byType(TextField).last, '12a34');
    await t.pump();
    expect(_otp(t), '1234'); // huruf dibuang
    expect(button().onPressed, isNull);

    await t.enterText(find.byType(TextField).last, '1234567890');
    await t.pump();
    expect(_otp(t), '123456'); // dibatasi 6 digit (juga untuk kode yang ditempel)
    expect(button().onPressed, isNotNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('kirim ulang: terkunci 30 detik dengan hitung mundur, lalu aktif dan mengisi ulang kode dev', (t) async {
    final fake = await _pumpLogin(t, ['111111', '222222']);
    await _send(t, '81299990001');

    expect(find.text('Kirim ulang kode (0:30)'), findsOneWidget);
    TextButton resend() => t.widget<TextButton>(find.ancestor(of: find.textContaining('Kirim ulang kode'), matching: find.byType(TextButton)));
    expect(resend().onPressed, isNull);

    await t.pump(const Duration(seconds: 10));
    expect(find.text('Kirim ulang kode (0:20)'), findsOneWidget);

    await t.pump(const Duration(seconds: 20));
    expect(find.text('Kirim ulang kode'), findsOneWidget);
    expect(resend().onPressed, isNotNull);

    await t.tap(find.text('Kirim ulang kode'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(fake.sentTo.length, 2);
    expect(_otp(t), '222222'); // kode dev baru terisi otomatis
    expect(find.text('Kirim ulang kode (0:30)'), findsOneWidget); // hitung mundur mulai lagi
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Ganti nomor kembali ke langkah nomor dan membatalkan hitung mundur', (t) async {
    await _pumpLogin(t, [null]);
    await _send(t, '81299990001');
    await t.tap(find.text('Ganti nomor'));
    await t.pump();

    expect(find.text('Kirim kode OTP'), findsOneWidget);
    expect(find.textContaining('Kirim ulang kode'), findsNothing);
    await t.pumpWidget(const SizedBox());
  });
}
