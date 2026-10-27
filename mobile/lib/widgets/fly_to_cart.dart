import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import '../models/models.dart';
import 'illustration.dart';
import 'motion.dart';

/// Target animasi "terbang ke keranjang": bilah keranjang di HomeShell (bila sedang tampil).
class CartTarget {
  CartTarget._();
  static final GlobalKey barKey = GlobalKey(debugLabel: 'cartBar');

  /// Tinggi bar bawah (lengkung + bar), dipakai menentukan titik cadangan bila bilah keranjang belum tampil.
  static const bottomBarHeight = 96.0;
}

/// Naik setiap kali sebuah item mendarat di keranjang; bilah keranjang dan lencana berdenyut saat nilainya berubah.
final ValueNotifier<int> cartPulse = ValueNotifier<int>(0);

Offset _target(Size screen, double bottomInset) {
  final box = CartTarget.barKey.currentContext?.findRenderObject();
  if (box is RenderBox && box.attached && box.hasSize) return box.localToGlobal(box.size.center(Offset.zero));
  // Bilah keranjang muncul tepat di atas bar bawah: titik cadangan = tengah posisinya nanti (tinggi tombol 52 + jarak 8).
  return Offset(screen.width / 2, screen.height - bottomInset - CartTarget.bottomBarHeight - 8 - 26);
}

Offset _bezier(Offset a, Offset c, Offset b, double t) {
  final u = 1 - t;
  return a * (u * u) + c * (2 * u * t) + b * (t * t);
}

/// Lingkaran berisi gambar produk melesat melengkung dari tombol (konteks pemanggil) ke bilah keranjang, lalu
/// memicu denyut ([cartPulse]). Aman dipanggil kapan saja: tanpa Overlay, tanpa ukuran, atau saat "kurangi animasi"
/// aktif, ia langsung memicu denyut tanpa gerakan dan tidak melempar error.
void flyToCart(BuildContext context, {required Product product, VoidCallback? onLand}) {
  void land() {
    cartPulse.value++;
    onLand?.call();
  }

  if (reduceMotion(context)) {
    land();
    return;
  }
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  final box = context.findRenderObject();
  if (overlay == null || box is! RenderBox || !box.attached || !box.hasSize) {
    land();
    return;
  }
  final start = box.localToGlobal(box.size.center(Offset.zero));
  final screen = MediaQuery.sizeOf(context);
  final inset = MediaQuery.paddingOf(context).bottom;
  final controller = AnimationController(vsync: overlay, duration: const Duration(milliseconds: 560));
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => AnimatedBuilder(
      animation: controller,
      builder: (_, _) {
        final t = Curves.easeInOutCubic.transform(controller.value);
        final end = _target(screen, inset);
        final control = Offset((start.dx + end.dx) / 2, math.min(start.dy, end.dy) - 120);
        final p = _bezier(start, control, end, t);
        final d = lerpDouble(46, 22, t)!;
        final opacity = t > .85 ? (1 - (t - .85) / .15).clamp(0.0, 1.0) : 1.0;
        return Positioned(
          left: p.dx - d / 2,
          top: p.dy - d / 2,
          width: d,
          height: d,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: Container(
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 8)]),
                child: ClipOval(child: ProductImage(product, size: d - 4, radius: 0)),
              ),
            ),
          ),
        );
      },
    ),
  );
  overlay.insert(entry);
  controller.forward().whenComplete(() {
    entry.remove();
    entry.dispose();
    controller.dispose();
    land();
  });
}

/// Membalas denyut keranjang dengan membal singkat (bilah keranjang dan lencana jumlah).
class PulseOnChange extends StatefulWidget {
  const PulseOnChange({super.key, required this.child, this.scale = 1.08});
  final Widget child;
  final double scale;

  @override
  State<PulseOnChange> createState() => _PulseOnChangeState();
}

class _PulseOnChangeState extends State<PulseOnChange> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final Animation<double> _s = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: widget.scale).chain(CurveTween(curve: Curves.easeOut)), weight: 35),
    TweenSequenceItem(tween: Tween(begin: widget.scale, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 65),
  ]).animate(_c);

  void _on() {
    if (mounted && !reduceMotion(context)) _c.forward(from: 0);
  }

  @override
  void initState() {
    super.initState();
    cartPulse.addListener(_on);
  }

  @override
  void dispose() {
    cartPulse.removeListener(_on);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(scale: _s, child: widget.child);
}
