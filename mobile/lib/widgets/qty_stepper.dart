import 'package:flutter/material.dart';
import 'haptics.dart';
import 'pulse.dart';

/// Pengatur jumlah (− n +) berbentuk pil. `onDelete` (opsional) mengganti tombol − menjadi ikon hapus saat jumlah di batas minimum.
class QtyStepper extends StatelessWidget {
  const QtyStepper({super.key, required this.value, required this.onChanged, this.min = 1, this.max = 20, this.onDelete, this.compact = false});
  final int value, min, max;
  final ValueChanged<int> onChanged;
  final VoidCallback? onDelete;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 34.0 : 40.0;
    final atMin = value <= min;
    final deleting = atMin && onDelete != null;
    Widget btn(IconData icon, VoidCallback? onTap, {Color? color}) => Material(
          color: Colors.white,
          shape: const CircleBorder(side: BorderSide(color: Color(0xFFCFE3E0))),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap == null
                ? null
                : () {
                    tapHaptic();
                    onTap();
                  },
            child: SizedBox(width: size, height: size, child: Icon(icon, size: compact ? 18 : 20, color: onTap == null ? const Color(0xFFB8C9C6) : (color ?? const Color(0xFF0F766E)))),
          ),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      btn(deleting ? Icons.delete_outline_rounded : Icons.remove_rounded, deleting ? onDelete : (atMin ? null : () => onChanged(value - 1)), color: deleting ? const Color(0xFFC2563B) : null),
      SizedBox(
        width: compact ? 34 : 42,
        // Angka bergeser halus lalu membal kecil setiap kali jumlah berubah.
        child: BounceOnChange(
          value: value,
          scale: 1.22,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
            child: Text('$value', key: ValueKey(value), textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: compact ? 15 : 17, color: const Color(0xFF0B2E2B))),
          ),
        ),
      ),
      btn(Icons.add_rounded, value >= max ? null : () => onChanged(value + 1)),
    ]);
  }
}
