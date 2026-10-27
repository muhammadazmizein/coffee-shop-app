import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kopi_app/core/theme.dart';
import 'package:kopi_app/models/models.dart';
import 'package:kopi_app/widgets/count_up.dart';
import 'package:kopi_app/widgets/fly_to_cart.dart';
import 'package:kopi_app/widgets/home_footer.dart';
import 'package:kopi_app/widgets/page_transitions.dart';
import 'package:kopi_app/widgets/pressable.dart';
import 'package:kopi_app/widgets/stagger.dart';
import 'package:kopi_app/widgets/tab_fade.dart';

/// Lapisan animasi/interaksi: Pressable, FadeSlideIn, CountUp, fly-to-cart, transisi halaman, TabFade, dan footer beranda.

/// Membungkus [child] dengan pengaturan "kurangi animasi" aktif.
Widget noAnim(Widget child) => Builder(
  builder: (c) => MediaQuery(
    data: MediaQuery.of(c).copyWith(disableAnimations: true),
    child: child,
  ),
);

Widget app(Widget body) => MaterialApp(
  theme: buildTheme(),
  home: Scaffold(body: body),
);

Product product() =>
    Product(id: 'p1', name: 'Kopi Susu', price: 22000, groups: const []);

double scaleOf(WidgetTester t) => t
    .widget<AnimatedScale>(
      find.descendant(
        of: find.byType(Pressable),
        matching: find.byType(AnimatedScale),
      ),
    )
    .scale;

double? opacityOf(WidgetTester t, {Finder? within}) {
  final f = find.descendant(
    of: within ?? find.byType(FadeSlideIn),
    matching: find.byType(Opacity),
  );
  return f.evaluate().isEmpty ? null : t.widget<Opacity>(f.first).opacity;
}

void main() {
  setUp(FadeSlideIn.resetPlayed);

  group('Pressable', () {
    testWidgets('memanggil onTap', (t) async {
      var taps = 0;
      await t.pumpWidget(
        app(
          Center(
            child: Pressable(
              onTap: () => taps++,
              child: const SizedBox(
                width: 100,
                height: 100,
                child: ColoredBox(color: Colors.teal),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.byType(Pressable));
      expect(taps, 1);
    });

    testWidgets('menyusut ke 0,97 saat ditekan dan kembali ke 1 saat dilepas', (
      t,
    ) async {
      await t.pumpWidget(
        app(
          const Center(
            child: Pressable(
              child: SizedBox(
                width: 100,
                height: 100,
                child: ColoredBox(color: Colors.teal),
              ),
            ),
          ),
        ),
      );
      expect(scaleOf(t), 1.0);
      final g = await t.startGesture(t.getCenter(find.byType(Pressable)));
      await t.pump(const Duration(milliseconds: 120));
      expect(scaleOf(t), 0.97);
      await g.up();
      await t.pump(const Duration(milliseconds: 500));
      expect(scaleOf(t), 1.0);
    });

    testWidgets('mode pasif tidak menelan ketukan tombol di dalamnya', (
      t,
    ) async {
      var pressed = 0;
      await t.pumpWidget(
        app(
          Center(
            child: Pressable(
              child: ElevatedButton(
                onPressed: () => pressed++,
                child: const Text('Ketuk'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Ketuk'));
      expect(pressed, 1);
    });

    testWidgets('jari yang bergeser jauh (menggulir) melepas efek tekan', (
      t,
    ) async {
      await t.pumpWidget(
        app(
          const Center(
            child: Pressable(
              child: SizedBox(
                width: 100,
                height: 100,
                child: ColoredBox(color: Colors.teal),
              ),
            ),
          ),
        ),
      );
      final g = await t.startGesture(t.getCenter(find.byType(Pressable)));
      await t.pump(const Duration(milliseconds: 120));
      expect(scaleOf(t), 0.97);
      await g.moveBy(const Offset(0, 60));
      await t.pump(const Duration(milliseconds: 500));
      expect(scaleOf(t), 1.0);
      await g.up();
    });

    testWidgets('"kurangi animasi": tidak menyusut', (t) async {
      await t.pumpWidget(
        app(
          noAnim(
            const Center(
              child: Pressable(
                child: SizedBox(
                  width: 100,
                  height: 100,
                  child: ColoredBox(color: Colors.teal),
                ),
              ),
            ),
          ),
        ),
      );
      final g = await t.startGesture(t.getCenter(find.byType(Pressable)));
      await t.pump(const Duration(milliseconds: 120));
      expect(scaleOf(t), 1.0);
      await g.up();
    });
  });

  group('FadeSlideIn', () {
    testWidgets('memudar masuk sekali dan tidak mengulang saat rebuild', (
      t,
    ) async {
      var n = 0;
      late StateSetter rebuild;
      await t.pumpWidget(
        app(
          StatefulBuilder(
            builder: (c, set) {
              rebuild = set;
              return FadeSlideIn(playKey: 'a', child: Text('isi $n'));
            },
          ),
        ),
      );
      expect(opacityOf(t), lessThan(1.0)); // awal: belum tampak penuh
      await t.pump(const Duration(seconds: 1));
      expect(opacityOf(t), 1.0);

      rebuild(
        () => n++,
      ); // rebuild dengan State yang sama: tidak boleh memulai ulang
      await t.pump(const Duration(milliseconds: 16));
      expect(find.text('isi 1'), findsOneWidget);
      expect(opacityOf(t), 1.0);
    });

    testWidgets(
      'kunci yang sudah pernah diputar langsung tampil penuh pada State baru',
      (t) async {
        await t.pumpWidget(
          app(
            FadeSlideIn(key: UniqueKey(), playKey: 'b', child: const Text('x')),
          ),
        );
        await t.pump(const Duration(seconds: 1));
        // State baru dengan kunci yang sama (mis. item digulir keluar lalu kembali): tanpa animasi sama sekali.
        await t.pumpWidget(
          app(
            FadeSlideIn(key: UniqueKey(), playKey: 'b', child: const Text('x')),
          ),
        );
        expect(find.byType(Opacity), findsNothing);
        expect(find.text('x'), findsOneWidget);
      },
    );

    testWidgets('indeks lebih besar muncul belakangan', (t) async {
      await t.pumpWidget(
        app(
          const Column(
            children: [
              FadeSlideIn(index: 0, playKey: 'i0', child: Text('awal')),
              FadeSlideIn(index: 6, playKey: 'i6', child: Text('akhir')),
            ],
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 220));
      final first = opacityOf(
        t,
        within: find.ancestor(
          of: find.text('awal'),
          matching: find.byType(FadeSlideIn),
        ),
      )!;
      final last = opacityOf(
        t,
        within: find.ancestor(
          of: find.text('akhir'),
          matching: find.byType(FadeSlideIn),
        ),
      )!;
      expect(first, greaterThan(last));
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('"kurangi animasi": langsung tampil penuh', (t) async {
      await t.pumpWidget(
        app(noAnim(const FadeSlideIn(playKey: 'r', child: Text('langsung')))),
      );
      expect(find.byType(Opacity), findsNothing);
      expect(find.text('langsung'), findsOneWidget);
    });
  });

  group('CountUp', () {
    Widget host(int v, {bool reduce = false}) {
      final w = Center(
        child: CountUpText(value: v, format: (n) => '$n poin'),
      );
      return app(reduce ? noAnim(w) : w);
    }

    testWidgets(
      'tampilan pertama langsung di nilai akhir, perubahan berhitung lalu berakhir di nilai baru',
      (t) async {
        await t.pumpWidget(host(10));
        expect(find.text('10 poin'), findsOneWidget);
        await t.pumpWidget(host(50));
        await t.pump(const Duration(milliseconds: 250));
        final mid = int.parse(
          RegExp(r'\d+')
              .firstMatch((t.widget<Text>(find.byType(Text)).data)!)!
              .group(0)!,
        );
        expect(mid, inExclusiveRange(10, 50)); // sedang berhitung
        await t.pump(const Duration(seconds: 2));
        expect(find.text('50 poin'), findsOneWidget);
      },
    );

    testWidgets('"kurangi animasi": langsung ke nilai baru', (t) async {
      await t.pumpWidget(host(10, reduce: true));
      await t.pumpWidget(host(50, reduce: true));
      await t.pump(const Duration(milliseconds: 16));
      expect(find.text('50 poin'), findsOneWidget);
    });

    testWidgets('AnimatedValue berakhir di nilai akhir', (t) async {
      Widget h(double v) => app(
        Center(
          child: AnimatedValue(
            value: v,
            builder: (_, x) => Text(x.toStringAsFixed(2)),
          ),
        ),
      );
      await t.pumpWidget(h(0.2));
      await t.pumpWidget(h(0.9));
      await t.pump(const Duration(seconds: 2));
      expect(find.text('0.90'), findsOneWidget);
    });
  });

  group('fly-to-cart', () {
    testWidgets(
      'tanpa bilah keranjang: tidak melempar, lingkaran terbang lalu hilang, denyut bertambah',
      (t) async {
        final before = cartPulse.value;
        await t.pumpWidget(
          app(
            Center(
              child: Builder(
                builder: (c) => ElevatedButton(
                  onPressed: () => flyToCart(c, product: product()),
                  child: const Text('terbang'),
                ),
              ),
            ),
          ),
        );
        await t.tap(find.text('terbang'));
        await t.pump(const Duration(milliseconds: 150));
        expect(find.byType(ClipOval), findsOneWidget); // sedang terbang
        await t.pump(const Duration(milliseconds: 800));
        expect(find.byType(ClipOval), findsNothing);
        expect(cartPulse.value, before + 1);
        expect(t.takeException(), isNull);
      },
    );

    testWidgets('mengarah ke bilah keranjang bila ada', (t) async {
      await t.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Builder(
                  builder: (c) => ElevatedButton(
                    onPressed: () => flyToCart(c, product: product()),
                    child: const Text('terbang'),
                  ),
                ),
              ),
            ),
            bottomNavigationBar: SizedBox(
              height: 80,
              child: Center(
                child: SizedBox(key: CartTarget.barKey, width: 200, height: 52),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('terbang'));
      await t.pump(); // frame pertama menetapkan waktu mulai ticker
      await t.pump(const Duration(milliseconds: 520)); // hampir tiba
      final dot = t.getCenter(find.byType(ClipOval));
      final bar = t.getCenter(find.byKey(CartTarget.barKey));
      expect((dot - bar).distance, lessThan(40));
      await t.pump(const Duration(seconds: 1));
    });

    testWidgets(
      'tanpa Overlay/Navigator: langsung mendarat dan tidak melempar',
      (t) async {
        final before = cartPulse.value;
        await t.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: MediaQuery(
              data: const MediaQueryData(),
              child: Builder(
                builder: (c) => GestureDetector(
                  onTap: () => flyToCart(c, product: product()),
                  child: const SizedBox(
                    width: 50,
                    height: 50,
                    child: ColoredBox(color: Colors.teal),
                  ),
                ),
              ),
            ),
          ),
        );
        await t.tap(find.byType(GestureDetector));
        await t.pump();
        expect(cartPulse.value, before + 1);
        expect(t.takeException(), isNull);
      },
    );

    testWidgets('"kurangi animasi": tanpa gerakan, langsung mendarat', (
      t,
    ) async {
      final before = cartPulse.value;
      await t.pumpWidget(
        app(
          noAnim(
            Center(
              child: Builder(
                builder: (c) => ElevatedButton(
                  onPressed: () => flyToCart(c, product: product()),
                  child: const Text('terbang'),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('terbang'));
      await t.pump();
      expect(find.byType(ClipOval), findsNothing);
      expect(cartPulse.value, before + 1);
    });

    testWidgets('PulseOnChange membal saat denyut bertambah', (t) async {
      await t.pumpWidget(
        app(
          const Center(
            child: PulseOnChange(
              scale: 1.5,
              child: SizedBox(width: 40, height: 40),
            ),
          ),
        ),
      );
      double s() => t
          .widget<ScaleTransition>(
            find.descendant(
              of: find.byType(PulseOnChange),
              matching: find.byType(ScaleTransition),
            ),
          )
          .scale
          .value;
      expect(s(), 1.0);
      cartPulse.value++;
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(s(), greaterThan(1.0));
      await t.pump(const Duration(seconds: 1));
      expect(s(), closeTo(1.0, 0.01));
    });
  });

  group('transisi halaman', () {
    GoRouter router() => GoRouter(
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (_, s) => fadePage(
            key: s.pageKey,
            child: Scaffold(
              body: Builder(
                builder: (c) => Center(
                  child: TextButton(
                    onPressed: () => c.push('/b'),
                    child: const Text('menuju B'),
                  ),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/b',
          pageBuilder: (_, s) => fadeThroughPage(
            key: s.pageKey,
            child: Scaffold(
              body: Builder(
                builder: (c) => Center(
                  child: TextButton(
                    onPressed: () => c.pop(),
                    child: const Text('halaman B'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    testWidgets('push lalu pop memakai fade-through tanpa error', (t) async {
      await t.pumpWidget(
        MaterialApp.router(routerConfig: router(), theme: buildTheme()),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('menuju B'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 120)); // di tengah transisi
      expect(find.text('halaman B'), findsOneWidget);
      await t.pumpAndSettle();
      expect(find.text('halaman B'), findsOneWidget);
      await t.tap(find.text('halaman B'));
      await t.pumpAndSettle();
      expect(find.text('halaman B'), findsNothing);
      expect(find.text('menuju B'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets(
      '"kurangi animasi": perpindahan tanpa FadeTransition transisi',
      (t) async {
        t.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
        await t.pumpWidget(
          MaterialApp.router(routerConfig: router(), theme: buildTheme()),
        );
        await t.pumpAndSettle();
        await t.tap(find.text('menuju B'));
        await t.pumpAndSettle();
        expect(find.text('halaman B'), findsOneWidget);
      },
    );
  });

  group('TabFade', () {
    testWidgets('state tab terjaga dan konten memudar singkat saat berganti', (
      t,
    ) async {
      late StateSetter set;
      var index = 0;
      await t.pumpWidget(
        app(
          StatefulBuilder(
            builder: (c, s) {
              set = s;
              return TabFade(
                index: index,
                children: const [
                  TextField(key: ValueKey('f')),
                  Center(child: Text('tab dua')),
                ],
              );
            },
          ),
        ),
      );
      await t.enterText(find.byKey(const ValueKey('f')), 'ketikan saya');

      set(() => index = 1);
      await t.pump();
      await t.pump(const Duration(milliseconds: 40));
      expect(
        t
            .widget<FadeTransition>(
              find
                  .descendant(
                    of: find.byType(TabFade),
                    matching: find.byType(FadeTransition),
                  )
                  .first,
            )
            .opacity
            .value,
        lessThan(1.0),
      );
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('tab dua'), findsOneWidget);

      set(() => index = 0);
      await t.pump(const Duration(milliseconds: 500));
      expect(
        find.text('ketikan saya'),
        findsOneWidget,
      ); // state TextField di tab pertama tidak hilang
    });
  });

  group('footer beranda', () {
    final full = Outlet(
      id: 'o',
      name: 'Outlet Sudirman',
      address: 'Jl. Jenderal Sudirman No. 1, Jakarta',
      openHour: 7,
      closeHour: 22,
      deliveryRadiusKm: 1,
      lat: -6.2088,
      lng: 106.8222,
      phone: '081355500001',
    );
    final bare = Outlet(
      id: 'o',
      name: 'Outlet Baru',
      address: 'Jl. Contoh No. 1',
      openHour: 7,
      closeHour: 22,
      deliveryRadiusKm: 0,
    );

    Widget host(Outlet? o) =>
        app(SingleChildScrollView(child: HomeFooter(outlet: o)));

    testWidgets('menampilkan merek, kartu outlet, cara pesan, dan versi', (
      t,
    ) async {
      await t.pumpWidget(host(full));
      for (final s in [
        'Outlet kami',
        'Outlet Sudirman',
        'Rute',
        'Telepon',
        'Cara pesan',
        'Pilih menu',
        'Bayar',
        'Ambil / Diantar',
        'Kopi App • v1.0',
      ]) {
        expect(find.textContaining(s), findsWidgets, reason: s);
      }
    });

    testWidgets(
      'tanpa telepon: tombol Telepon tidak ada; tanpa outlet: kartu outlet tidak ada',
      (t) async {
        await t.pumpWidget(host(bare));
        expect(find.text('Rute'), findsOneWidget);
        expect(find.text('Telepon'), findsNothing);
        await t.pumpWidget(host(null));
        expect(find.text('Outlet kami'), findsNothing);
        expect(find.text('Cara pesan'), findsOneWidget);
      },
    );

    testWidgets('gagal membuka peta menampilkan SnackBar, bukan error', (
      t,
    ) async {
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        (_) async => false,
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          null,
        ),
      );
      await t.pumpWidget(host(full));
      await t.tap(find.text('Rute'));
      await t.pump(const Duration(milliseconds: 50));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Tidak bisa membuka peta'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('layar paling sempit dan font besar tidak meluap', (t) async {
      t.view.physicalSize = const Size(320, 800) * 2.625;
      t.view.devicePixelRatio = 2.625;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c)
                .copyWith(textScaler: const TextScaler.linear(1.15)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(child: HomeFooter(outlet: full)),
          ),
        ),
      );
      expect(t.takeException(), isNull);
    });

    test('directionsUri memakai koordinat bila ada, jika tidak alamat', () {
      expect(
        directionsUri(full).toString(),
        'https://www.google.com/maps/dir/?api=1&destination=-6.2088,106.8222',
      );
      final u = directionsUri(bare);
      expect(u.host, 'www.google.com');
      expect(u.queryParameters['destination'], 'Jl. Contoh No. 1');
    });

    test('telUri menormalkan nomor lokal dan internasional', () {
      expect(telUri('081355500001').toString(), 'tel:+6281355500001');
      expect(telUri('+62 813-5550-0001').toString(), 'tel:+6281355500001');
      expect(telUri('6281355500001').toString(), 'tel:+6281355500001');
      expect(telUri(''), isNull);
      expect(telUri('12'), isNull);
      expect(telUri(null), isNull);
    });
  });

  group('Outlet.fromJson (field baru)', () {
    Map<String, dynamic> base() => {
      'id': 'o',
      'name': 'N',
      'address': 'A',
      'openHour': 7,
      'closeHour': 22,
      'deliveryRadiusKm': '1',
    };

    test('server lama tanpa lat/lng/phone tetap terbaca', () {
      final o = Outlet.fromJson(base());
      expect(o.lat, isNull);
      expect(o.lng, isNull);
      expect(o.phone, isNull);
    });

    test('lat/lng bisa string Decimal maupun angka; phone kosong dianggap tidak ada', () {
      final a = Outlet.fromJson({
        ...base(),
        'lat': '-6.2088',
        'lng': 106.8222,
        'phone': ' 08123 ',
      });
      expect(a.lat, -6.2088);
      expect(a.lng, 106.8222);
      expect(a.phone, '08123');
      expect(Outlet.fromJson({...base(), 'phone': '  '}).phone, isNull);
      expect(Outlet.fromJson({...base(), 'lat': 'bukan angka'}).lat, isNull);
    });
  });
}
