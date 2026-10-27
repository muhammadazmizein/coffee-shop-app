import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../state/providers.dart';
import '../widgets/async_view.dart';

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Alamat Pengiriman')),
      body: AsyncView<List<Address>>(
        value: addresses,
        onRetry: () => ref.invalidate(addressesProvider),
        builder: (list) => RefreshIndicator(
          onRefresh: () => ref.refresh(addressesProvider.future),
          child: list.isEmpty
              ? ListView(children: [
                  const SizedBox(height: 110),
                  Icon(Icons.location_off_outlined, size: 72, color: Colors.black.withValues(alpha: .25)),
                  const SizedBox(height: 12),
                  const Center(child: Text('Belum ada alamat tersimpan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                  const SizedBox(height: 4),
                  const Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 40), child: Text('Tambahkan alamat untuk pesanan yang diantar kurir.', textAlign: TextAlign.center))),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final a = list[i];
                    return Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFD5EBE8))),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(width: 42, height: 42, decoration: BoxDecoration(color: brandColor.withValues(alpha: .1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.location_on_rounded, color: brandColor)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(a.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                            Text(a.recipient, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(a.detail, style: Theme.of(context).textTheme.bodySmall),
                          ]),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Hapus alamat?'),
                                content: Text('"${a.label}" akan dihapus. Alamat yang pernah dipakai pesanan tidak bisa dihapus.'),
                                actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus'))],
                              ),
                            );
                            if (ok != true) return;
                            try {
                              await ref.read(apiProvider).delete('/addresses/${a.id}');
                              ref.invalidate(addressesProvider);
                              ref.read(authProvider.notifier).refreshProfile();
                            } catch (e) {
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                            }
                          },
                        ),
                      ]),
                    );
                  },
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/addresses/new');
          ref.invalidate(addressesProvider);
          ref.read(authProvider.notifier).refreshProfile();
        },
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Tambah alamat'),
      ),
    );
  }
}
