import 'package:flutter/widgets.dart';
import 'motion.dart';

/// Muncul dengan fade + geser kecil ke atas, berjeda menurut [index] (maks 8 × 45 ms).
///
/// Hanya diputar SEKALI untuk setiap [playKey]: bila kunci yang sama sudah pernah diputar (mis. item digulir keluar
/// lalu kembali, atau halaman dibangun ulang), anak langsung tampil penuh. Tanpa [playKey], diputar sekali per State.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0, this.playKey, this.dy = 14});
  final Widget child;
  final int index;
  final String? playKey;
  final double dy;

  static final Set<String> _played = <String>{};

  /// Dipakai test untuk mengosongkan catatan "sudah diputar".
  static void resetPlayed() => _played.clear();

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  static const _dur = 380;
  AnimationController? _c;
  Animation<double>? _t;
  bool _decided = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decided) return;
    _decided = true;
    final key = widget.playKey;
    final skip = reduceMotion(context) || (key != null && FadeSlideIn._played.contains(key));
    if (key != null) FadeSlideIn._played.add(key);
    if (skip) return; // tampil penuh langsung
    final delay = widget.index.clamp(0, 8) * 45;
    final c = AnimationController(vsync: this, duration: Duration(milliseconds: delay + _dur));
    _c = c;
    _t = CurvedAnimation(parent: c, curve: Interval(delay / (delay + _dur), 1.0, curve: Curves.easeOutCubic));
    c.forward();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    if (t == null) return widget.child;
    return AnimatedBuilder(
      animation: t,
      child: widget.child,
      builder: (_, child) => Opacity(
        opacity: t.value.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - t.value) * widget.dy), child: child),
      ),
    );
  }
}
