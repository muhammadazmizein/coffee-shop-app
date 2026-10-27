import 'package:flutter/material.dart';

import '../core/format.dart';
import '../models/models.dart';
import 'haptics.dart';
import 'pulse.dart';
import 'section_card.dart';

/// Chip pilihan opsi: nama + tambahan harga. Pilihan tunggal berbentuk kartu, pilihan ganda bertanda centang.
class OptionChip extends StatelessWidget {
  const OptionChip({
    super.key,
    required this.option,
    required this.selected,
    required this.multi,
    required this.onTap,
  });
  final Option option;
  final bool selected, multi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFF0F766E);
    return BounceOnChange(
      value: selected,
      scale: 1.07,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE2F6F2) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? brand : const Color(0xFFCFE3E0),
            width: selected ? 2 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (multi) ...[
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.add_circle_outline_rounded,
                      size: 20,
                      color: selected ? brand : const Color(0xFF8AA09D),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          option.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            color: selected ? brand : kInk,
                          ),
                        ),
                        if (option.extraPrice > 0)
                          Text(
                            '+${rupiah(option.extraPrice)}',
                            style: const TextStyle(fontSize: 12, color: kMuted),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Satu grup opsi: judul, lencana Wajib/Opsional, dan chip-chipnya. `warning` menampilkan pesan batas pilihan.
class OptionGroupCard extends StatelessWidget {
  const OptionGroupCard({
    super.key,
    required this.group,
    required this.selected,
    required this.onToggle,
    this.warning = false,
  });
  final OptionGroup group;
  final Set<String> selected;
  final void Function(Option) onToggle;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final multi = group.maxSelect > 1;
    final missing = group.required && selected.isEmpty;
    return SectionCard(
      title: group.name,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: group.required
              ? (missing ? const Color(0xFFFCE4DE) : const Color(0xFFE2F6F2))
              : const Color(0xFFF0F4F3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          group.required
              ? 'Wajib'
              : 'Opsional${multi ? ' • maks ${group.maxSelect}' : ''}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: group.required
                ? (missing ? const Color(0xFFC2563B) : const Color(0xFF0F766E))
                : kMuted,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in group.options)
                OptionChip(
                  option: o,
                  selected: selected.contains(o.id),
                  multi: multi,
                  onTap: () {
                    tapHaptic();
                    onToggle(o);
                  },
                ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            child: warning
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'Maksimal ${group.maxSelect} pilihan untuk ${group.name}.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFFC2563B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
