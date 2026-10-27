import 'package:flutter/material.dart';

/// Angka yang "menghitung" menuju nilai barunya (mis. total, subtotal, poin).
/// `from` bila diisi membuat hitungan juga berjalan pada tampilan pertama (mulai dari nilai itu).
/// Mengikuti pengaturan "kurangi animasi" perangkat: langsung menampilkan nilai akhir.
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    this.from,
    this.format,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.duration = const Duration(milliseconds: 650),
  });

  final num value;
  final num? from;
  final String Function(int)? format;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final Duration duration;

  String _fmt(int v) => format != null ? format!(v) : '$v';

  @override
  Widget build(BuildContext context) {
    Widget text(int v) => Text(_fmt(v), style: style, textAlign: textAlign, maxLines: maxLines, overflow: overflow);
    if (MediaQuery.disableAnimationsOf(context)) return text(value.round());
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: from?.toDouble(), end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => text(v.round()),
    );
  }
}
