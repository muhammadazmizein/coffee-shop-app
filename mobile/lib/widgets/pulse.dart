import 'package:flutter/material.dart';

/// Denyut lembut berulang (skala dan/atau kepekatan). Berhenti saat `active` false, saat widget dibuang,
/// dan bila perangkat meminta animasi dikurangi.
class Pulse extends StatefulWidget {
  const Pulse({super.key, required this.child, this.active = true, this.minScale = 1.0, this.maxScale = 1.06, this.minOpacity = 1.0, this.period = const Duration(milliseconds: 1100)});
  final Widget child;
  final bool active;
  final double minScale, maxScale, minOpacity;
  final Duration period;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period);

  bool get _run => widget.active && !MediaQuery.disableAnimationsOf(context);

  void _sync() {
    if (_run) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(Pulse old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
    return AnimatedBuilder(
      animation: curve,
      child: widget.child,
      builder: (_, child) => Opacity(
        opacity: 1 - (1 - widget.minOpacity) * curve.value,
        child: Transform.scale(scale: widget.minScale + (widget.maxScale - widget.minScale) * curve.value, child: child),
      ),
    );
  }
}

/// Membal kecil (1 → 1,18 → 1) setiap kali `value` berubah. Pada tampilan pertama tidak membal.
class BounceOnChange extends StatefulWidget {
  const BounceOnChange({super.key, required this.value, required this.child, this.scale = 1.18});
  final Object? value;
  final Widget child;
  final double scale;

  @override
  State<BounceOnChange> createState() => _BounceOnChangeState();
}

class _BounceOnChangeState extends State<BounceOnChange> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));

  @override
  void didUpdateWidget(BounceOnChange old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && !MediaQuery.disableAnimationsOf(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: widget.scale).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: widget.scale, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 60),
    ]).animate(_c);
    return ScaleTransition(scale: s, child: widget.child);
  }
}
