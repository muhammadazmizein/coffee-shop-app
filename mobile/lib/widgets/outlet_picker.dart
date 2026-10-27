import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../state/providers.dart';

/// Jam sekarang di WIB (0-23); jadwal outlet dibuat dalam WIB.
int wibHour() => DateTime.now().toUtc().add(const Duration(hours: 7)).hour;

bool outletOpenNow(Outlet o) {
  final h = wibHour();
  return o.openHour <= o.closeHour ? h >= o.openHour && h < o.closeHour : h >= o.openHour || h < o.closeHour;
}

String hourLabel(int h) => '${(h % 24).toString().padLeft(2, '0')}.00';

/// Pilih outlet. Keranjang dikosongkan (setelah konfirmasi) karena menu tiap outlet bisa berbeda.
Future<void> pickOutlet(BuildContext context, WidgetRef ref) async {
  final outlets = ref.read(outletsProvider).value;
  if (outlets == null) return;
  final current = ref.read(selectedOutletProvider);
  final picked = await showModalBottomSheet<Outlet>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final o in outlets)
            ListTile(
              leading: const Icon(Icons.store),
              title: Text(o.name),
              subtitle: Text('${o.address}\n${outletOpenNow(o) ? 'Buka' : 'Tutup'} • ${hourLabel(o.openHour)} - ${hourLabel(o.closeHour)}'
                  '${o.deliveryRadiusKm > 0 ? ' • Delivery' : ''}'),
              isThreeLine: true,
              trailing: o.id == current?.id ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, o),
            ),
        ],
      ),
    ),
  );
  if (picked == null || picked.id == current?.id || !context.mounted) return;

  if (ref.read(cartProvider).isNotEmpty) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ganti outlet?'),
        content: const Text('Keranjang akan dikosongkan karena menu tiap outlet bisa berbeda.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ganti')),
        ],
      ),
    );
    if (ok != true) return;
    ref.read(cartProvider.notifier).clear();
  }
  ref.read(selectedOutletProvider.notifier).select(picked);
}
