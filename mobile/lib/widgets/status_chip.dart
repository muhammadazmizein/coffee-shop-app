import 'package:flutter/material.dart';
import '../models/models.dart';

/// Warna + ikon satu status pesanan. Status tidak pernah dibawakan oleh warna saja: selalu ikon + label.
class StatusStyle {
  const StatusStyle(this.color, this.icon);
  final Color color;
  final IconData icon;
}

StatusStyle statusStyle(String status) => switch (status) {
      'PENDING_PAYMENT' => const StatusStyle(Color(0xFFB26A00), Icons.hourglass_top_rounded),
      'PAID' => const StatusStyle(Color(0xFF0F766E), Icons.payments_rounded),
      'PREPARING' => const StatusStyle(Color(0xFF0F766E), Icons.local_cafe_rounded),
      'READY' => const StatusStyle(Color(0xFF2F7A3E), Icons.shopping_bag_rounded),
      'ON_DELIVERY' => const StatusStyle(Color(0xFF1D6FA3), Icons.delivery_dining_rounded),
      'COMPLETED' => const StatusStyle(Color(0xFF2F7A3E), Icons.check_circle_rounded),
      'CANCELLED' => const StatusStyle(Color(0xFFC2563B), Icons.cancel_rounded),
      'EXPIRED' => const StatusStyle(Color(0xFF8A6D3B), Icons.timer_off_rounded),
      _ => const StatusStyle(Color(0xFF50706C), Icons.info_rounded),
    };

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, required this.type});
  final String status, type;

  @override
  Widget build(BuildContext context) {
    final s = statusStyle(status);
    // Saat status berganti, chip lama memudar dan chip baru muncul dengan sedikit membesar.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: ScaleTransition(scale: Tween<double>(begin: .85, end: 1).animate(anim), child: child)),
      child: KeyedSubtree(key: ValueKey(status), child: _chip(s)),
    );
  }

  Widget _chip(StatusStyle s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: s.color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(s.icon, size: 15, color: s.color),
        const SizedBox(width: 5),
        Flexible(child: Text(statusLabel(status, type), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: s.color, fontWeight: FontWeight.w800, fontSize: 12.5))),
      ]),
    );
  }
}
