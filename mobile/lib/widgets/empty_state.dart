import 'package:flutter/material.dart';
import 'illustration.dart';

/// Keadaan kosong/error yang ramah: ilustrasi (atau ikon), judul, penjelasan, dan tombol aksi opsional.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, this.illustration, this.icon = Icons.inbox_outlined, required this.title, this.message, this.actionLabel, this.onAction});
  final String? illustration; // nama aset di assets/illustrations (tanpa .svg)
  final IconData icon;
  final String title;
  final String? message, actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (illustration != null)
            Illustration(illustration!, width: 180, height: 180)
          else
            Container(width: 96, height: 96, decoration: const BoxDecoration(color: Color(0xFFE5F6F3), shape: BoxShape.circle), child: Icon(icon, size: 44, color: theme.colorScheme.primary)),
          const SizedBox(height: 18),
          Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF50706C), height: 1.4)),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            FilledButton(onPressed: onAction, style: FilledButton.styleFrom(minimumSize: const Size(180, 48)), child: Text(actionLabel!)),
          ],
        ]),
      ),
    );
  }
}
