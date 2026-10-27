import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kopi_app/models/models.dart';
import 'package:kopi_app/state/favorites.dart';
import 'package:kopi_app/state/providers.dart';
import 'package:kopi_app/widgets/category_row.dart';
import 'package:kopi_app/widgets/hero_tags.dart';
import 'package:kopi_app/widgets/product_card.dart';

Product _product({bool required = false}) => Product(
      id: 'p1',
      name: 'Kopi Susu Gula Aren',
      price: 22000,
      groups: required ? [OptionGroup(id: 'g', name: 'Ukuran', required: true, maxSelect: 1, options: [Option(id: 'o', name: 'Regular', extraPrice: 0)])] : const [],
    );

class _MemStore extends FavoritesStore {
  _MemStore([this.value]);
  String? value;
  int writes = 0;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String v) async {
    value = v;
    writes++;
  }
}

void main() {
  group('needsOptions', () {
    test('produk tanpa grup opsi langsung bisa ditambah', () => expect(needsOptions(_product()), isFalse));
    test('grup wajib berarti butuh halaman detail', () => expect(needsOptions(_product(required: true)), isTrue));
    test('grup opsional saja tidak menghalangi tambah cepat', () {
      final p = Product(id: 'x', name: 'X', price: 1, groups: [OptionGroup(id: 'g', name: 'Topping', required: false, maxSelect: 2, options: const [])]);
      expect(needsOptions(p), isFalse);
    });
  });

  group('favorit', () {
    test('serialisasi urut dan tahan data rusak', () {
      expect(encodeFavorites({'b', 'a'}), '["a","b"]');
      expect(decodeFavorites('["a","b"]'), {'a', 'b'});
      expect(decodeFavorites(null), isEmpty);
      expect(decodeFavorites(''), isEmpty);
      expect(decodeFavorites('bukan json'), isEmpty);
      expect(decodeFavorites('{"a":1}'), isEmpty);
      expect(decodeFavorites('["a",1,null,"b"]'), {'a', 'b'});
    });

    test('toggle menambah/menghapus dan menyimpan', () async {
      final store = _MemStore();
      final c = ProviderContainer(overrides: [favoritesStoreProvider.overrideWithValue(store)]);
      addTearDown(c.dispose);
      final n = c.read(favoritesProvider.notifier);
      n.toggle('p1');
      n.toggle('p2');
      expect(c.read(favoritesProvider), {'p1', 'p2'});
      n.toggle('p1');
      expect(c.read(favoritesProvider), {'p2'});
      expect(store.value, '["p2"]');
      expect(store.writes, 3);
    });

    test('data tersimpan dimuat saat mulai, tanpa menimpa toggle yang terjadi selama memuat', () async {
      final c = ProviderContainer(overrides: [favoritesStoreProvider.overrideWithValue(_MemStore('["a","b"]'))]);
      addTearDown(c.dispose);
      c.read(favoritesProvider.notifier).toggle('z'); // sebelum pemuatan selesai
      await Future<void>.delayed(Duration.zero);
      expect(c.read(favoritesProvider), {'a', 'b', 'z'});
    });
  });

  group('categoryIcon', () {
    test('memilih ikon dari kata kunci nama kategori', () {
      expect(categoryIcon('Kopi'), Icons.coffee_rounded);
      expect(categoryIcon('Non-Kopi'), Icons.local_drink_rounded);
      expect(categoryIcon('Teh & Segar'), Icons.emoji_food_beverage_rounded);
      expect(categoryIcon('Makanan'), Icons.bakery_dining_rounded);
      expect(categoryIcon('Dessert'), Icons.cake_rounded);
      expect(categoryIcon('Sesuatu Baru'), Icons.local_cafe_rounded); // cadangan
    });
  });

  group('ProductCard', () {
    Widget app(Widget home, {List<Override> overrides = const []}) {
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, _) => Scaffold(body: home)),
        GoRoute(path: '/product', builder: (_, s) => Scaffold(body: Center(child: Hero(tag: productHeroTag((s.extra as Product).id), child: const SizedBox(width: 120, height: 120, child: ColoredBox(color: Colors.teal)))))),
        GoRoute(path: '/cart', builder: (_, _) => const Scaffold(body: Text('keranjang'))),
      ]);
      return ProviderScope(overrides: [favoritesStoreProvider.overrideWithValue(_MemStore()), ...overrides], child: MaterialApp.router(routerConfig: router));
    }

    Future<void> size(WidgetTester t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 2.625;
      addTearDown(t.view.reset);
    }

    testWidgets('tombol + langsung menambah produk tanpa opsi wajib ke keranjang', (t) async {
      await size(t);
      await t.pumpWidget(app(Center(child: SizedBox(width: 180, height: 260, child: ProductCard(_product())))));
      final container = ProviderScope.containerOf(t.element(find.byType(ProductCard)));
      expect(container.read(cartProvider), isEmpty);

      await t.tap(find.byIcon(Icons.add_rounded));
      await t.pump();
      expect(container.read(cartProvider).single.product.id, 'p1');
      expect(container.read(cartProvider).single.qty, 1);
      expect(find.textContaining('ditambahkan'), findsOneWidget);

      await t.tap(find.byIcon(Icons.add_rounded)); // ketuk lagi: baris yang sama digabung
      await t.pump();
      expect(container.read(cartProvider).single.qty, 2);
      // Animasi "terbang ke keranjang" (±560 ms) harus selesai sebelum widget dibongkar.
      await t.pump(const Duration(seconds: 1));
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('produk dengan opsi wajib: + membuka detail, keranjang tetap kosong', (t) async {
      await size(t);
      await t.pumpWidget(app(Center(child: SizedBox(width: 180, height: 260, child: ProductCard(_product(required: true))))));
      final container = ProviderScope.containerOf(t.element(find.byType(ProductCard)));
      await t.tap(find.byIcon(Icons.add_rounded));
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      await t.pumpAndSettle();
      expect(container.read(cartProvider), isEmpty);
      expect(find.byType(Hero), findsOneWidget); // sekarang di halaman detail
      await t.pump(const Duration(seconds: 1));
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('hati favorit mengubah daftar favorit', (t) async {
      await size(t);
      await t.pumpWidget(app(Center(child: SizedBox(width: 180, height: 260, child: ProductCard(_product())))));
      final container = ProviderScope.containerOf(t.element(find.byType(ProductCard)));
      await t.tap(find.byIcon(Icons.favorite_border_rounded));
      await t.pump();
      expect(container.read(favoritesProvider), {'p1'});
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('lencana tampil bila diberikan', (t) async {
      await size(t);
      await t.pumpWidget(app(Center(child: SizedBox(width: 180, height: 260, child: ProductCard(_product(), badge: 'Terlaris')))));
      expect(find.text('Terlaris'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('produk yang sama di dua tempat tidak membuat transisi Hero error', (t) async {
      await size(t);
      // Mirip beranda: produk yang sama muncul di baris Terlaris dan di grid kategori pada halaman yang sama.
      await t.pumpWidget(app(Column(children: [
        SizedBox(width: 180, height: 250, child: ProductCard(_product(), badge: 'Terlaris')),
        SizedBox(width: 180, height: 250, child: ProductCard(_product())),
      ])));
      expect(find.byType(Hero), findsNothing); // tidak ada Hero ganda saat diam

      await t.tap(find.byType(ProductCard).first);
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byType(Hero), findsOneWidget);

      // Kembali ke halaman sebelumnya juga tanpa error, dan Hero dilepas setelah animasi selesai.
      final nav = Navigator.of(t.element(find.byType(Hero)));
      nav.pop();
      await t.pumpAndSettle();
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull);
      expect(find.byType(Hero), findsNothing);
      await t.pumpWidget(const SizedBox());
    });
  });
}
