import 'package:flutter/material.dart';

/// Masuk sekali: memudar dan bergeser ringan, dengan jeda (untuk efek berundak).
/// Memakai satu AnimationController (jeda lewat Interval) sehingga tidak ada timer yang menggantung.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.delay = Duration.zero, this.duration = const Duration(milliseconds: 420), this.offset = const Offset(0, 14)});
  final Widget child;
  final Duration delay, duration;
  final Offset offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.delay + widget.duration);
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Interval(_total == 0 ? 0 : widget.delay.inMilliseconds / _total, 1, curve: Curves.easeOutCubic),
  );
  bool _started = false;

  int get _total => (widget.delay + widget.duration).inMilliseconds;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (_, child) => Opacity(
        opacity: _t.value.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(widget.offset.dx * (1 - _t.value), widget.offset.dy * (1 - _t.value)), child: child),
      ),
    );
  }
}
