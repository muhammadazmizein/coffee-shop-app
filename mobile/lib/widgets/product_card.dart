import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../models/models.dart';
import '../state/favorites.dart';
import '../state/providers.dart';
import 'fly_to_cart.dart';
import 'haptics.dart';
import 'hero_tags.dart';
import 'illustration.dart';
import 'motion.dart';
import 'pressable.dart';
import 'stagger.dart';

/// Faktor skala font dari pengaturan HP (dibatasi), dipakai agar tinggi kartu ikut membesar bersama teksnya.
double textScale(BuildContext c) =>
    MediaQuery.textScalerOf(c).scale(1).clamp(1.0, 1.3);

/// Produk dengan grup opsi wajib (ukuran, gula, dst.) tidak bisa langsung ditambah dari kartu.
bool needsOptions(Product p) => p.groups.any((g) => g.required);

/// Pemilik Hero saat ini. Produk yang sama bisa tampil di beberapa tempat sekaligus (Terlaris, grid beranda, tab Menu),
/// padahal dua Hero bertag sama dalam satu halaman membuat navigasi error. Jadi hanya kartu yang diketuk
/// yang dibungkus Hero selama transisi.
final ValueNotifier<Object?> _heroOwner = ValueNotifier<Object?>(null);

class ProductCard extends ConsumerStatefulWidget {
  const ProductCard(this.product, {super.key, this.badge});
  final Product product;

  /// Lencana kecil di pojok kiri atas gambar, mis. "Terlaris".
  final String? badge;

  @override
  ConsumerState<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<ProductCard> {
  final Object _id = Object();

  Future<void> _open() async {
    _heroOwner.value = _id;
    await WidgetsBinding.instance.endOfFrame; // beri satu frame agar Hero terpasang sebelum berpindah halaman
    if (!mounted) {
      if (_heroOwner.value == _id) _heroOwner.value = null;
      return;
    }
    await context.push('/product', extra: widget.product);
    // Pertahankan Hero sampai animasi kembali selesai.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (_heroOwner.value == _id) _heroOwner.value = null;
  }

  void _quickAdd(BuildContext buttonContext) {
    final p = widget.product;
    if (needsOptions(p)) {
      _open();
      return;
    }
    ref
        .read(cartProvider.notifier)
        .add(CartLine(product: p, options: const [], qty: 1));
    successHaptic();
    flyToCart(buttonContext, product: p);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${p.name} ditambahkan'),
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'Lihat',
            onPressed: () => context.push('/cart'),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = widget.product;
    final fav = ref.watch(favoritesProvider.select((s) => s.contains(p.id)));
    return Pressable(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _open,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ValueListenableBuilder<Object?>(
                        valueListenable: _heroOwner,
                        builder: (_, owner, _) {
                          final image = ProductImage(p, radius: 18);
                          return owner == _id
                              ? Hero(tag: productHeroTag(p.id), child: image)
                              : image;
                        },
                      ),
                    ),
                    if (widget.badge != null)
                      Positioned(top: 8, left: 8, child: _Badge(widget.badge!)),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: _RoundButton(
                        size: 32,
                        color: Colors.white.withValues(alpha: .92),
                        tooltip: fav
                            ? 'Hapus dari favorit'
                            : 'Tambah ke favorit',
                        bounce: true,
                        onTap: (_) {
                          tapHaptic();
                          ref.read(favoritesProvider.notifier).toggle(p.id);
                        },
                        child: Icon(
                          fav
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 19,
                          color: fav
                              ? const Color(0xFFE0573A)
                              : const Color(0xFF50706C),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: _RoundButton(
                        size: 36,
                        color: theme.colorScheme.primary,
                        tooltip: needsOptions(p)
                            ? 'Pilih opsi'
                            : 'Tambah ke keranjang',
                        bounce: true,
                        onTap: _quickAdd,
                        child: const Icon(
                          Icons.add_rounded,
                          size: 22,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                p.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                rupiah(p.price),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE0573A), Color(0xFFF59E0B)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            size: 13,
            color: Colors.white,
          ),
          const SizedBox(width: 3),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tombol bulat kecil di atas gambar; [bounce] membuatnya membal singkat saat diketuk.
class _RoundButton extends StatefulWidget {
  const _RoundButton({
    required this.size,
    required this.color,
    required this.child,
    required this.onTap,
    required this.tooltip,
    this.bounce = false,
  });
  final double size;
  final Color color;
  final Widget child;
  final void Function(BuildContext buttonContext) onTap;
  final String tooltip;
  final bool bounce;

  @override
  State<_RoundButton> createState() => _RoundButtonState();
}

class _RoundButtonState extends State<_RoundButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.32,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.32,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.elasticOut)),
      weight: 65,
    ),
  ]).animate(_c);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Tooltip(
        message: widget.tooltip,
        child: Material(
          color: widget.color,
          shape: const CircleBorder(),
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: .25),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              if (widget.bounce && !reduceMotion(context)) _c.forward(from: 0);
              widget.onTap(context);
            },
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Center(child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Seksi per kategori: judul + grid 2 kolom. `limit` membatasi jumlah produk (beranda); null = semua (tab Menu).
/// [popularIds] memberi lencana "Terlaris" pada produk yang ada di dalamnya.
List<Widget> productSections(
  BuildContext context,
  List<Category> categories, {
  int? limit,
  void Function(Category c)? onSeeAll,
  Set<String> popularIds = const {},
  String keyPrefix = 'grid',
}) {
  final theme = Theme.of(context);
  final out = <Widget>[];
  for (final c in categories) {
    final items = limit == null ? c.products : c.products.take(limit).toList();
    out.add(
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  c.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (onSeeAll != null && c.products.length > items.length)
                TextButton(
                  onPressed: () => onSeeAll(c),
                  child: const Text('Lihat semua'),
                ),
            ],
          ),
        ),
      ),
    );
    out.add(
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid.builder(
          // Tinggi tile dihitung dari lebar layar dan skala font (bukan rasio tetap), supaya nama 2 baris + harga selalu muat.
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent:
                (MediaQuery.sizeOf(context).width - 32 - 12) / 2 +
                66 * textScale(context),
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => FadeSlideIn(
            index: i,
            playKey: '$keyPrefix-${items[i].id}',
            child: ProductCard(
              items[i],
              badge: popularIds.contains(items[i].id) ? 'Terlaris' : null,
            ),
          ),
        ),
      ),
    );
  }
  return out;
}
