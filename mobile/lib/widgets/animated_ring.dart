import 'package:flutter/material.dart';

/// Cincin progres yang bergerak halus menuju nilai barunya (0..1); pada tampilan pertama terisi dari 0.
/// Mengikuti pengaturan "kurangi animasi" perangkat.
class AnimatedProgressRing extends StatelessWidget {
  const AnimatedProgressRing({super.key, required this.value, this.strokeWidth = 5, this.backgroundColor, required this.color, this.duration = const Duration(milliseconds: 800)});
  final double value;
  final double strokeWidth;
  final Color? backgroundColor;
  final Color color;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    Widget ring(double v) => CircularProgressIndicator(value: v, strokeWidth: strokeWidth, backgroundColor: backgroundColor, valueColor: AlwaysStoppedAnimation(color));
    if (MediaQuery.disableAnimationsOf(context)) return ring(value);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => ring(v),
    );
  }
}
