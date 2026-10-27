import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/config.dart';
import '../models/models.dart';

/// Ilustrasi vektor bawaan (dibuat oleh tool/gen_*.py).
class Illustration extends StatelessWidget {
  const Illustration(this.name, {super.key, this.width, this.height, this.fit = BoxFit.contain});
  final String name;
  final double? width, height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) =>
      SvgPicture.asset('assets/illustrations/$name.svg', width: width, height: height, fit: fit);
}

/// Memilih ilustrasi bawaan dari nama/kategori produk. Dipakai hanya bila produk belum punya foto.
/// Urutan pemeriksaan penting: bentuk spesifik (mis. "chocolate croissant") harus dicek sebelum kata umum ("chocolate").
String productIllustration(Product p) {
  final n = p.name.toLowerCase();
  final c = (p.categoryName ?? '').toLowerCase();
  bool has(List<String> keys) => keys.any(n.contains);

  // Makanan
  if (n.contains('croissant')) {
    if (n.contains('choco') || n.contains('coklat') || n.contains('cokelat')) return 'product_chococroissant';
    if (n.contains('almond')) return 'product_almondcroissant';
    return 'product_croissant';
  }
  if (has(['donut', 'donat'])) {
    return has(['choco', 'coklat', 'cokelat']) ? 'product_donutchoco' : 'product_donut';
  }
  if (n.contains('cookie') && !n.contains('cream')) return 'product_cookie';
  if (has(['sandwich', 'burger', 'roti isi'])) return 'product_sandwich';
  if (has(['bread', 'toast', 'roti'])) return 'product_bread';

  // Minuman panas
  if (has(['espresso']) && !n.contains('macchiato')) return 'product_espresso';
  if (has(['jasmine', 'tea hot', 'hot tea', 'teh panas'])) return 'product_hottea';
  if (has(['flat white', 'cappuccino', 'capuccino', 'cappucino', 'cafe latte', 'hot'])) {
    return n.contains('cappuccino') || n.contains('capuccino') || n.contains('cappucino') ? 'product_cappuccino' : 'product_hotlatte';
  }

  // Minuman dingin
  if (has(['matcha', 'green tea'])) return 'product_matcha';
  if (has(['taro'])) return 'product_taro';
  if (has(['red velvet'])) return 'product_redvelvet';
  if (has(['thai tea'])) return 'product_thaitea';
  if (n.contains('cookies') && n.contains('cream')) return 'product_cookiescream';
  if (has(['strawberry', 'stroberi'])) return 'product_strawberry';
  if (has(['lemon'])) return 'product_lemontea';
  if (has(['lychee', 'leci', 'peach'])) return 'product_lychee';
  if (has(['boba', 'bubble', 'pearl', 'brown sugar'])) return 'product_boba';
  if (has(['mocha', 'mokaccino'])) return 'product_mocha';
  if (has(['caramel', 'karamel', 'hazelnut', 'butterscotch'])) return 'product_caramel';
  if (has(['coklat', 'cokelat', 'chocolate', 'choco'])) return 'product_chocolate';
  if (has(['americano', 'black', 'long black'])) return 'product_americano';

  if (c.contains('makanan') || c.contains('food') || c.contains('snack')) return 'product_croissant';
  return 'product_latte';
}

/// Foto produk dari server bila ada; jika tidak ada atau gagal dimuat, tampilkan ilustrasi bawaan.
class ProductImage extends StatelessWidget {
  const ProductImage(this.product, {super.key, this.size, this.radius = 14});
  final Product product;

  /// Kosong = isi lebar yang tersedia (persegi).
  final double? size;
  final double radius;

  /// URL relatif ("/uploads/x.jpg") digabung dengan alamat server.
  static String? resolve(String? url) {
    if (url == null || url.isEmpty) return null;
    return url.startsWith('/') ? '$apiUrl$url' : url;
  }

  @override
  Widget build(BuildContext context) {
    if (size != null) return _build(context, size!);
    return LayoutBuilder(builder: (context, c) => _build(context, c.maxWidth.isFinite ? c.maxWidth : 120));
  }

  Widget _build(BuildContext context, double size) {
    final fallback = Illustration(productIllustration(product), width: size, height: size);
    final url = resolve(product.imageUrl);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: url == null
            ? fallback
            : Image.network(
                url,
                fit: BoxFit.cover,
                // Foto besar diperkecil saat decode agar hemat memori.
                cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
                loadingBuilder: (_, child, progress) => progress == null ? child : fallback,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}
