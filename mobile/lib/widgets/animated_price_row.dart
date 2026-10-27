import 'package:flutter/material.dart';
import 'animated_number.dart';
import 'section_card.dart';
import '../core/format.dart';

/// Seperti PriceRow, tetapi nilainya (rupiah) menghitung menuju angka baru saat berubah.
/// `prefix` untuk tanda, mis. "-" pada potongan.
class AnimatedPriceRow extends StatelessWidget {
  const AnimatedPriceRow(this.label, this.value, {super.key, this.prefix = '', this.bold = false, this.color});
  final String label;
  final int value;
  final String prefix;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final style = (bold ? t.titleMedium?.copyWith(fontWeight: FontWeight.w800) : t.bodyMedium)?.copyWith(color: color ?? (bold ? kInk : kMuted));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(label, style: style)),
        const SizedBox(width: 12),
        AnimatedNumber(value: value, format: (v) => '$prefix${rupiah(v)}', style: style?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
    );
  }
}
