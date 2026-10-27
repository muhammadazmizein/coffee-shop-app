import 'package:flutter/material.dart';

import '../models/models.dart';
import 'pressable.dart';

/// Ikon kategori dipilih dari kata kunci nama (nama kategori bisa diubah admin), dengan cadangan umum.
IconData categoryIcon(String name) {
  final n = name.toLowerCase();
  bool has(List<String> k) => k.any(n.contains);
  if (has([
    'non-kopi',
    'non kopi',
    'susu',
    'milk',
    'cokelat',
    'coklat',
    'choco',
  ])) {
    return Icons.local_drink_rounded;
  }
  if (has(['teh', 'tea', 'segar', 'fresh', 'juice', 'jus'])) {
    return Icons.emoji_food_beverage_rounded;
  }
  if (has(['kopi', 'coffee', 'espresso'])) return Icons.coffee_rounded;
  if (has(['makanan', 'food', 'roti', 'bakery', 'pastry', 'snack', 'camilan'])) {
    return Icons.bakery_dining_rounded;
  }
  if (has(['dessert', 'cake', 'kue', 'manis'])) return Icons.cake_rounded;
  if (has(['merch', 'merchandise'])) return Icons.local_mall_rounded;
  return Icons.local_cafe_rounded;
}

const _palette = [
  Color(0xFF0F766E),
  Color(0xFF5B63C9),
  Color(0xFFD99A1E),
  Color(0xFFC2563B),
  Color(0xFF2F7A3E),
  Color(0xFF7C8FA0),
];

/// Baris kategori berikon di beranda. Ketuk satu kategori memanggil [onTap].
class CategoryRow extends StatelessWidget {
  const CategoryRow({super.key, required this.categories, required this.onTap});
  final List<Category> categories;
  final void Function(Category c) onTap;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 96 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final c = categories[i];
          final color = _palette[i % _palette.length];
          return Pressable(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onTap(c),
              child: SizedBox(
                width: 72,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(categoryIcon(c.name), color: color, size: 28),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
