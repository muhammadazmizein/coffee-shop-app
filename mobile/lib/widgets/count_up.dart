import 'package:flutter/widgets.dart';
import 'motion.dart';

/// Angka yang berhitung halus ke nilai terbaru saat [value] berubah (tampilan pertama langsung di nilai akhir).
class CountUpText extends StatelessWidget {
  const CountUpText({super.key, required this.value, this.style, this.format, this.maxLines, this.overflow, this.duration = const Duration(milliseconds: 700)});
  final int value;
  final TextStyle? style;
  final String Function(int n)? format;
  final int? maxLines;
  final TextOverflow? overflow;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.toDouble()),
      duration: motionDuration(context, duration),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) {
        final n = v.round();
        return Text(format != null ? format!(n) : '$n', style: style, maxLines: maxLines, overflow: overflow);
      },
    );
  }
}

/// Bilah progres 0..1 yang bergerak halus ke nilai terbaru; [builder] menerima nilai yang sedang berjalan.
class AnimatedValue extends StatelessWidget {
  const AnimatedValue({super.key, required this.value, required this.builder, this.duration = const Duration(milliseconds: 650)});
  final double value;
  final Widget Function(BuildContext context, double v) builder;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value),
      duration: motionDuration(context, duration),
      curve: Curves.easeOutCubic,
      builder: (ctx, v, _) => builder(ctx, v),
    );
  }
}
