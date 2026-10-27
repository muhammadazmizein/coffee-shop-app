import 'package:flutter/material.dart';

const kCardBorder = Color(0xFFD5EBE8);
const kInk = Color(0xFF0B2E2B);
const kMuted = Color(0xFF50706C);

/// Kartu putih bergaris tipis dengan judul bagian; dipakai di detail produk, keranjang, dan checkout.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, this.trailing, this.icon, required this.child, this.padding = const EdgeInsets.all(16)});
  final String? title;
  final Widget? trailing;
  final IconData? icon;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: kCardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null) ...[
          Row(children: [
            if (icon != null) ...[Icon(icon, size: 20, color: const Color(0xFF0F766E)), const SizedBox(width: 8)],
            Expanded(child: Text(title!, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: kInk))),
            ?trailing,
          ]),
          const SizedBox(height: 12),
        ],
        child,
      ]),
    );
  }
}

/// Satu baris rincian harga (label kiri, nilai kanan).
class PriceRow extends StatelessWidget {
  const PriceRow(this.label, this.value, {super.key, this.bold = false, this.color});
  final String label, value;
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
        Text(value, style: style?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
    );
  }
}
