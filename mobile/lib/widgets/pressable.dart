import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'motion.dart';

/// Pembungkus yang menyusutkan anak sedikit (±0,97) saat ditekan, lalu mengembalikannya dengan pegas.
///
/// Dua mode:
///  - [onTap] diisi: widget ini yang menangani ketukan.
///  - [onTap] kosong ("pasif"): hanya efek skala; ketukan tetap ditangani anak (mis. InkWell/tombol di dalamnya).
/// Bila jari bergeser jauh (menggulir), efek tekan dilepas supaya kartu tidak menyusut saat daftar digulir.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scaleDown = 0.97});
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  Offset? _start;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotion(context);
    Widget c = AnimatedScale(
      scale: _down && !reduce ? widget.scaleDown : 1.0,
      duration: reduce ? Duration.zero : (_down ? const Duration(milliseconds: 90) : const Duration(milliseconds: 340)),
      curve: _down ? Curves.easeOut : Curves.elasticOut,
      child: widget.child,
    );
    c = Listener(
      onPointerDown: (e) {
        _start = e.position;
        _set(true);
      },
      onPointerMove: (e) {
        if (_start != null && (e.position - _start!).distance > kTouchSlop) _set(false);
      },
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: c,
    );
    if (widget.onTap != null) c = GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onTap, child: c);
    return c;
  }
}
