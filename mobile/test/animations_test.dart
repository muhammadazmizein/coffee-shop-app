import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopi_app/core/api.dart';
import 'package:kopi_app/core/format.dart';
import 'package:kopi_app/core/theme.dart';
import 'package:kopi_app/models/models.dart';
import 'package:kopi_app/screens/pay_screen.dart';
import 'package:kopi_app/screens/profile_screen.dart';
import 'package:kopi_app/state/providers.dart';
import 'package:kopi_app/widgets/animated_number.dart';
import 'package:kopi_app/widgets/entrance.dart';
import 'package:kopi_app/widgets/order_tracker.dart';
import 'package:kopi_app/widgets/particle_burst.dart';
import 'package:kopi_app/widgets/pulse.dart';

/// Animasi perayaan dan mikro-interaksi: harus selesai/berhenti sendiri, tidak meninggalkan timer,
/// mengikuti "kurangi animasi", dan tidak merusak tata letak. Bila env SNAP_DIR diisi, simpan PNG beberapa titik waktu.
final _fonts = '${Platform.environment['HOME']}/development/flutter/bin/cache/artifacts/material_fonts';

Future<void> _loadFonts() async {
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

OrderView _order(String status) => OrderView(
      id: 'o1', code: 'KPMVKMVP365846', type: 'PICKUP', status: status, total: 58900, subtotal: 62000, discount: 0, deliveryFee: 0, pointsUsed: 0,
      createdAt: DateTime(2026, 10, 25, 14, 20), items: const [],
    );

class _FakeAuth extends AuthNotifier {
  @override
  Future<UserProfile?> build() async => UserProfile(id: 'u', phone: '6281299990001', name: 'Azmi', points: 120, completionPercent: 40);
}

/// Api palsu: hanya jalur yang dipakai test.
class _FakeApi extends Api {
  _FakeApi() : super(onUnauthorized: () {});
  int checkInPosts = 0;

  @override
  Future<T> get<T>(String path, T Function(dynamic) parse, {Map<String, dynamic>? query, bool auth = false}) async {
    if (path == '/me') return parse({'id': 'u', 'phone': '6281299990001', 'name': 'Azmi', 'points': 123, 'unreadNotifications': 0, 'profileCompletion': {'percent': 40, 'missing': ['email']}});
    throw ApiException('tidak dipakai di test: $path');
  }

  @override
  Future<T> post<T>(String path, Object? body, T Function(dynamic) parse, {bool auth = false}) async {
    if (path == '/me/checkin') {
      checkInPosts++;
      return parse({'today': '2026-10-26', 'claimedToday': true, 'streak': 4, 'dayInCycle': 4, 'nextPoints': 1, 'awarded': 3, 'rewards': _rewards(claimedUpTo: 4)});
    }
    throw ApiException('tidak dipakai di test: $path');
  }
}

List<Map<String, dynamic>> _rewards({required int claimedUpTo}) => [
      for (var d = 1; d <= 7; d++) {'day': d, 'points': d == 7 ? 5 : 1, 'claimed': d <= claimedUpTo},
    ];

CheckInView _checkIn() => CheckInView.fromJson({'today': '2026-10-26', 'claimedToday': false, 'streak': 3, 'dayInCycle': 4, 'nextPoints': 3, 'rewards': _rewards(claimedUpTo: 3)});

Membership _membership() {
  final tiers = [Tier(id: 't0', name: 'Member', minSpend: 0, earnMultiplierPct: 100, discountPct: 0), Tier(id: 't1', name: 'Silver', minSpend: 500000, earnMultiplierPct: 125, discountPct: 3, maxDiscount: 10000)];
  return Membership(lifetimeSpend: 100000, current: tiers[0], next: tiers[1], remainingToNext: 400000, progressPct: 20, tiers: tiers);
}

void main() {
  setUpAll(() async {
    await _loadFonts();
    await initializeDateFormatting('id_ID');
  });

  Widget app(Widget home, {List<Override> overrides = const [], double fontScale = 1.0, bool reduce = false}) => ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: buildTheme(),
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(fontScale), disableAnimations: reduce), child: child!),
          home: home,
        ),
      );

  // ---------- komponen ----------

  testWidgets('ParticleBurst selesai, memanggil onDone, lalu tidak menjadwalkan frame lagi', (t) async {
    var done = 0;
    await t.pumpWidget(MaterialApp(home: SizedBox.expand(child: ParticleBurst(duration: const Duration(milliseconds: 500), onDone: () => done++))));
    await t.pump(const Duration(milliseconds: 250));
    expect(done, 0);
    await t.pump(const Duration(milliseconds: 400));
    expect(done, 1);
    await t.pumpAndSettle(); // tidak boleh menggantung: tidak ada animasi berulang
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('AnimatedNumber menghitung lalu berakhir di nilai akhir, dan mengikuti perubahan nilai', (t) async {
    Widget n(int v) => MaterialApp(home: Center(child: AnimatedNumber(value: v, from: 0, format: rupiah, duration: const Duration(milliseconds: 600))));
    await t.pumpWidget(n(1000));
    expect(find.text('Rp0'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 250));
    final mid = (t.widget<Text>(find.byType(Text)).data!);
    expect(mid, isNot('Rp0'));
    expect(mid, isNot('Rp1.000'));
    await t.pumpAndSettle();
    expect(find.text('Rp1.000'), findsOneWidget);
    await t.pumpWidget(n(2500));
    await t.pumpAndSettle();
    expect(find.text('Rp2.500'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('"Kurangi animasi": angka, masuk berundak, dan partikel langsung ke keadaan akhir', (t) async {
    await t.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Column(children: [
          AnimatedNumber(value: 4200, from: 0, format: rupiah),
          const FadeSlideIn(delay: Duration(milliseconds: 500), child: Text('halo')),
          const SizedBox(width: 100, height: 100, child: ParticleBurst()),
        ]),
      ),
    ));
    expect(find.text('Rp4.200'), findsOneWidget); // tanpa menunggu
    final fade = t.widget<Opacity>(find.ancestor(of: find.text('halo'), matching: find.byType(Opacity)).first);
    expect(fade.opacity, 1);
    expect(t.binding.transientCallbackCount, 0); // tidak ada animasi yang berjalan
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Pulse berhenti saat active=false dan saat dibuang; BounceOnChange membal hanya saat nilai berubah', (t) async {
    Widget p(bool active) => MaterialApp(home: Pulse(active: active, child: const Text('x')));
    await t.pumpWidget(p(true));
    await t.pump(const Duration(milliseconds: 300));
    expect(t.binding.transientCallbackCount, greaterThan(0)); // berdenyut
    await t.pumpWidget(p(false));
    await t.pumpAndSettle(); // berhenti
    expect(t.binding.transientCallbackCount, 0);

    Widget b(int v) => MaterialApp(home: BounceOnChange(value: v, child: Text('$v')));
    await t.pumpWidget(b(1));
    expect(t.binding.transientCallbackCount, 0); // tampilan pertama tidak membal
    await t.pumpWidget(b(2));
    await t.pump(const Duration(milliseconds: 50));
    expect(t.binding.transientCallbackCount, greaterThan(0));
    await t.pumpAndSettle();
    await t.pumpWidget(const SizedBox());
    expect(t.binding.transientCallbackCount, 0);
  });

  testWidgets('Pelacak: langkah berubah memicu isian garis ulang tanpa error, dan semua animasi berhenti saat dibuang', (t) async {
    Widget tr(String s) => MaterialApp(home: Padding(padding: const EdgeInsets.all(16), child: OrderTracker(status: s, type: 'PICKUP')));
    await t.pumpWidget(tr('PAID'));
    await t.pump(const Duration(seconds: 2));
    await t.pumpWidget(tr('READY'));
    await t.pump(const Duration(seconds: 2));
    await t.pumpWidget(tr('COMPLETED'));
    await t.pump(const Duration(seconds: 2));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    expect(t.binding.transientCallbackCount, 0);
  });

  // ---------- layar sukses ----------

  for (final (size, label) in [(const Size(411, 914), 'HP biasa'), (const Size(360, 640), 'layar kecil')]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('layar sukses bayar • $label • font ${scale}x: tanpa overflow, angka berakhir, confetti berhenti', (t) async {
        t.view.physicalSize = size * 2.625;
        t.view.devicePixelRatio = 2.625;
        addTearDown(t.view.reset);
        await t.pumpWidget(app(const PayScreen(orderId: 'o1'), fontScale: scale, overrides: [orderProvider.overrideWith((ref, id) async => _order('PAID'))]));
        await t.pump(const Duration(milliseconds: 100));
        await t.pump(const Duration(milliseconds: 300)); // tengah animasi
        expect(t.takeException(), isNull);
        await t.pump(const Duration(seconds: 3)); // semua selesai (confetti ≤ 2,5 dtk)
        expect(find.text(rupiah(58900)), findsOneWidget);
        expect(find.text('Pembayaran berhasil'), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox()); // hentikan timer polling/hitung mundur layar bayar
      });
    }
  }

  testWidgets('layar gagal/kedaluwarsa tidak memunculkan confetti dan tidak overflow', (t) async {
    await t.pumpWidget(app(const PayScreen(orderId: 'o1'), overrides: [orderProvider.overrideWith((ref, id) async => _order('EXPIRED'))]));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byType(ParticleBurst), findsNothing);
    expect(find.text('Waktu pembayaran habis'), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('layar sukses dengan "kurangi animasi": langsung final', (t) async {
    await t.pumpWidget(app(const PayScreen(orderId: 'o1'), reduce: true, overrides: [orderProvider.overrideWith((ref, id) async => _order('PAID'))]));
    await t.pump();
    await t.pump();
    expect(find.text(rupiah(58900)), findsOneWidget);
    expect(find.text('Lihat pesanan'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  // ---------- check-in ----------

  testWidgets('klaim check-in: percikan koin + dialog "+3 poin" muncul, tanpa error, lalu bisa ditutup', (t) async {
    t.view.physicalSize = const Size(411, 1400) * 2.625;
    t.view.devicePixelRatio = 2.625;
    addTearDown(t.view.reset);
    final api = _FakeApi();
    await t.pumpWidget(app(const ProfileTab(), overrides: [
      apiProvider.overrideWith((ref) => api),
      authProvider.overrideWith(_FakeAuth.new),
      checkInProvider.overrideWith((ref) async => _checkIn()),
      membershipProvider.overrideWith((ref) async => _membership()),
      inboxProvider.overrideWith((ref) async => Inbox(unread: 0, items: const [])),
    ]));
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Check-in sekarang'), findsOneWidget);

    await t.tap(find.textContaining('Check-in sekarang'));
    await t.pump(); // permintaan klaim
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 500)); // dialog + percikan berjalan
    expect(api.checkInPosts, 1);
    expect(find.text('Mantap'), findsOneWidget);
    expect(t.takeException(), isNull);

    await t.pump(const Duration(seconds: 2)); // angka "+3 poin" selesai menghitung
    expect(find.text('+3 poin'), findsOneWidget);
    await t.tap(find.text('Mantap'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Mantap'), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('check-in "kurangi animasi": dialog tetap muncul dan angka langsung final', (t) async {
    t.view.physicalSize = const Size(411, 1400) * 2.625;
    t.view.devicePixelRatio = 2.625;
    addTearDown(t.view.reset);
    await t.pumpWidget(app(const ProfileTab(), reduce: true, overrides: [
      apiProvider.overrideWith((ref) => _FakeApi()),
      authProvider.overrideWith(_FakeAuth.new),
      checkInProvider.overrideWith((ref) async => _checkIn()),
      membershipProvider.overrideWith((ref) async => _membership()),
      inboxProvider.overrideWith((ref) async => Inbox(unread: 0, items: const [])),
    ]));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    await t.tap(find.textContaining('Check-in sekarang'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('+3 poin'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  // ---------- render PNG (hanya bila SNAP_DIR) ----------

  Future<void> snap(WidgetTester t, GlobalKey key, String name) async {
    final dir = Platform.environment['SNAP_DIR'];
    if (dir == null) return;
    await t.runAsync(() async {
      final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await b.toImage(pixelRatio: 1.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  testWidgets('PNG: layar sukses pada beberapa titik waktu', (t) async {
    if (Platform.environment['SNAP_DIR'] == null) return;
    t.view.physicalSize = const Size(411, 760) * 2.625;
    t.view.devicePixelRatio = 2.625;
    addTearDown(t.view.reset);
    final key = GlobalKey();
    await t.pumpWidget(RepaintBoundary(key: key, child: app(const PayScreen(orderId: 'o1'), overrides: [orderProvider.overrideWith((ref, id) async => _order('PAID'))])));
    await t.pump(const Duration(milliseconds: 50));
    for (final (ms, name) in [(250, 'sukses-1-muncul'), (450, 'sukses-2-centang'), (700, 'sukses-3-confetti'), (1500, 'sukses-4-akhir')]) {
      await t.pump(Duration(milliseconds: ms));
      await snap(t, key, name);
    }
    await t.pump(const Duration(seconds: 3));
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('PNG: check-in sebelum dan sesudah klaim (percikan koin)', (t) async {
    if (Platform.environment['SNAP_DIR'] == null) return;
    t.view.physicalSize = const Size(411, 900) * 2.625;
    t.view.devicePixelRatio = 2.625;
    addTearDown(t.view.reset);
    final key = GlobalKey();
    await t.pumpWidget(RepaintBoundary(key: key, child: app(const ProfileTab(), overrides: [
      apiProvider.overrideWith((ref) => _FakeApi()),
      authProvider.overrideWith(_FakeAuth.new),
      checkInProvider.overrideWith((ref) async => _checkIn()),
      membershipProvider.overrideWith((ref) async => _membership()),
      inboxProvider.overrideWith((ref) async => Inbox(unread: 0, items: const [])),
    ])));
    await t.pump(const Duration(milliseconds: 600));
    await snap(t, key, 'checkin-1-sebelum');
    await t.tap(find.textContaining('Check-in sekarang'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 150));
    await snap(t, key, 'checkin-2-percikan');
    await t.pump(const Duration(milliseconds: 700));
    await snap(t, key, 'checkin-3-dialog');
    await t.pump(const Duration(seconds: 3));
    await t.pumpWidget(const SizedBox());
  });
}
