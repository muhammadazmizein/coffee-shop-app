import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'motion.dart';

/// Bar bawah dengan tab terpilih berupa lingkaran yang menonjol di atas lengkung bar.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({super.key, required this.index, required this.onTap, this.badgeIndex});
  final int index;
  final ValueChanged<int> onTap;

  /// Tab yang diberi titik merah (mis. ada notifikasi belum dibaca).
  final int? badgeIndex;

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Beranda'),
    (Icons.menu_book_outlined, Icons.menu_book_rounded, 'Menu'),
    (Icons.workspace_premium_outlined, Icons.workspace_premium_rounded, 'Member'),
    (Icons.local_mall_outlined, Icons.local_mall_rounded, 'Merch'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Saya'),
  ];

  static const _bump = 32.0; // ruang lengkung di atas garis bar
  static const _barH = 64.0;
  static const circleR = 29.0; // jari-jari lingkaran tab terpilih
  static const gap = 7.0; // celah putih antara lingkaran dan busur
  static const dip = 6.0; // pusat lingkaran sedikit di bawah garis bar

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context).bottom;
    // Label bar tidak boleh ikut membesar terlalu jauh, kalau tidak 5 tab tidak muat.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.0,
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        final itemW = w / _items.length;
        double cx(int i) => itemW * (i + .5);
        return SizedBox(
          height: _bump + _barH + inset,
          child: Stack(children: [
            TweenAnimationBuilder<double>(
              tween: Tween(end: cx(index)),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              builder: (_, x, _) => CustomPaint(size: Size(w, _bump + _barH + inset), painter: _BarPainter(x)),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(end: cx(index)),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              builder: (_, x, _) => Positioned(
                left: x - circleR,
                top: _bump + dip - circleR,
                child: Container(
                  width: circleR * 2,
                  height: circleR * 2,
                  decoration: const BoxDecoration(color: Color(0xFFCFF3EE), shape: BoxShape.circle),
                  // Ikon membal singkat (pegas) setiap kali tab berganti; key membuat animasi mulai ulang.
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(index),
                    tween: Tween(begin: 0.55, end: 1.0),
                    duration: motionDuration(context, const Duration(milliseconds: 460)),
                    curve: Curves.elasticOut,
                    builder: (_, v, child) => Transform.scale(scale: v, child: child),
                    child: Icon(_items[index].$2, color: brandColor, size: 28),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              top: _bump,
              bottom: inset,
              child: Row(children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: InkWell(
                      onTap: () => onTap(i),
                      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                        Stack(clipBehavior: Clip.none, children: [
                          Opacity(opacity: i == index ? 0 : 1, child: Icon(_items[i].$1, size: 26, color: const Color(0xFF8AA09D))),
                          if (badgeIndex == i && i != index) Positioned(right: -2, top: -1, child: Container(width: 10, height: 10, decoration: BoxDecoration(color: const Color(0xFFD33F3F), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)))),
                        ]),
                        const SizedBox(height: 2),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(_items[i].$3, maxLines: 1, style: TextStyle(fontSize: 12, fontWeight: i == index ? FontWeight.w800 : FontWeight.w600, color: i == index ? brandColor : const Color(0xFF8AA09D))),
                        ),
                      ]),
                    ),
                  ),
              ]),
            ),
          ]),
        );
      }),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.cx);
  final double cx;

  @override
  void paint(Canvas canvas, Size size) {
    const top = AppBottomBar._bump;
    const r = AppBottomBar.circleR + AppBottomBar.gap; // busur sepusat dengan lingkaran
    final cy = top + AppBottomBar.dip;
    // Busur dimulai/berakhir di 200° dan 340° (simetris terhadap puncak di 270°); sambungan halus ke garis bar.
    const a0 = 200 * math.pi / 180;
    const sweep = 140 * math.pi / 180;
    final sx = cx + r * math.cos(a0), sy = cy + r * math.sin(a0); // titik awal busur (kiri)
    final ex = cx + r * math.cos(a0 + sweep), ey = cy + r * math.sin(a0 + sweep); // titik akhir busur (kanan)
    final edge = Path()
      ..moveTo(0, top)
      ..lineTo(sx - 16, top)
      ..quadraticBezierTo(sx - 2.4, top + .3, sx, sy)
      ..arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: r), a0, sweep, false)
      ..quadraticBezierTo(ex + 2.4, top + .3, ex + 16, top)
      ..lineTo(size.width, top);
    final fill = Path.from(edge)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawShadow(fill, Colors.black.withValues(alpha: .3), 6, false);
    canvas.drawPath(fill, Paint()..color = Colors.white);
    canvas.drawPath(edge, Paint()..color = const Color(0xFFD5EBE8)..style = PaintingStyle.stroke..strokeWidth = 1.2);
    // Titik ey dipakai agar kedua ujung busur terbukti simetris (lihat test).
    assert((ey - sy).abs() < 1e-6);
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.cx != cx;
}
