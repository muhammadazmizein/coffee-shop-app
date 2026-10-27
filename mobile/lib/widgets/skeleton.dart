import 'package:flutter/material.dart';

/// Kotak abu-abu berkilau sebagai pengganti spinner saat data dimuat.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 16, this.radius = 10});
  final double? width;
  final double height, radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final t = _c.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1.5 + 3 * t, 0),
              end: Alignment(-0.5 + 3 * t, 0),
              colors: const [Color(0xFFE3EEEC), Color(0xFFF3F9F8), Color(0xFFE3EEEC)],
            ),
          ),
        );
      },
    );
  }
}

/// Kerangka kartu produk (gambar persegi + 2 baris teks), untuk grid menu.
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(aspectRatio: 1, child: Skeleton(height: double.infinity, radius: 18)),
        SizedBox(height: 10),
        Skeleton(width: 120, height: 14),
        SizedBox(height: 6),
        Skeleton(width: 70, height: 14),
      ]),
    );
  }
}

/// Kerangka baris daftar (foto bulat + 2 baris teks), untuk keranjang, pesanan, dll.
class ListRowSkeleton extends StatelessWidget {
  const ListRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Skeleton(width: 56, height: 56, radius: 16),
        SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Skeleton(height: 14), SizedBox(height: 8), Skeleton(width: 120, height: 12)])),
      ]),
    );
  }
}
