import 'package:flutter_test/flutter_test.dart';
import 'package:kopi_app/models/models.dart';
import 'package:kopi_app/widgets/illustration.dart';

String art(String name, {String? category}) =>
    productIllustration(Product(id: 'x', name: name, price: 1, categoryName: category, groups: const []));

void main() {
  group('Pemetaan nama produk -> ilustrasi', () {
    test('menu seed memakai gambar yang sesuai', () {
      const expected = {
        'Kopi Susu Gula Aren': 'product_latte',
        'Americano': 'product_americano',
        'Cappuccino': 'product_cappuccino',
        'Cafe Latte': 'product_hotlatte',
        'Flat White': 'product_hotlatte',
        'Caramel Macchiato': 'product_caramel',
        'Mocha Latte': 'product_mocha',
        'Hazelnut Latte': 'product_caramel',
        'Butterscotch Latte': 'product_caramel',
        'Vietnam Drip Ice': 'product_latte',
        'Espresso Single': 'product_espresso',
        'Matcha Latte': 'product_matcha',
        'Chocolate': 'product_chocolate',
        'Taro Milk': 'product_taro',
        'Red Velvet Latte': 'product_redvelvet',
        'Thai Tea': 'product_thaitea',
        'Cookies & Cream': 'product_cookiescream',
        'Strawberry Milk': 'product_strawberry',
        'Brown Sugar Boba Milk': 'product_boba',
        'Lemon Tea': 'product_lemontea',
        'Lychee Tea': 'product_lychee',
        'Peach Tea': 'product_lychee',
        'Jasmine Tea Hot': 'product_hottea',
        'Croissant Butter': 'product_croissant',
        'Chocolate Croissant': 'product_chococroissant',
        'Almond Croissant': 'product_almondcroissant',
        'Glazed Donut': 'product_donut',
        'Chocolate Donut': 'product_donutchoco',
        'Choco Chip Cookie': 'product_cookie',
        'Banana Bread': 'product_bread',
        'Chicken Mayo Sandwich': 'product_sandwich',
        'Cheese Toast': 'product_bread',
      };
      expected.forEach((name, want) => expect(art(name), want, reason: name));
    });

    test('produk tak dikenal: makanan -> croissant, lainnya -> latte', () {
      expect(art('Menu Baru', category: 'Makanan'), 'product_croissant');
      expect(art('Menu Baru', category: 'Kopi'), 'product_latte');
    });
  });

  group('Format voucher', () {
    VoucherView v(String type, int value, {int min = 0, int? max}) =>
        VoucherView(code: 'X', type: type, value: value, minSpend: min, maxDiscount: max, endsAt: DateTime(2030));

    test('persen dengan minimum dan batas maksimum', () {
      final x = v('PERCENT', 10, min: 30000, max: 15000);
      expect(x.headline, 'Diskon 10%');
      expect(x.detail, 'Min. belanja Rp30.000 • maks Rp15.000');
    });
    test('nominal tanpa minimum', () {
      final x = v('FIXED', 5000);
      expect(x.headline, 'Potongan Rp5.000');
      expect(x.detail, 'Tanpa minimum belanja');
    });
  });

  test('PromoSlide membaca field opsional', () {
    final p = PromoSlide.fromJson({'title': 'T', 'body': 'B', 'imageUrl': null, 'art': 'onboarding_1', 'ctaLabel': null, 'voucherCode': 'HEMAT10'});
    expect(p.voucherCode, 'HEMAT10');
    expect(p.imageUrl, isNull);
  });
}
