import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'async_view.dart';
import '../state/providers.dart';

class VoucherCard extends ConsumerWidget {
  const VoucherCard(this.v, {super.key, this.wide = false});
  final VoucherView v;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      width: wide ? null : 300,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBFE3DD)),
      ),
      child: Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFC2563B).withValues(alpha: .12), shape: BoxShape.circle), child: const Icon(Icons.local_offer, color: Color(0xFFC2563B))),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v.headline, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            Text(v.detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
            const SizedBox(height: 2),
            Text('Kode ${v.code}', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelMedium?.copyWith(color: const Color(0xFFC2563B), fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () {
            ref.read(pendingVoucherProvider.notifier).set(v.code);
            if (wide) Navigator.pop(context);
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text('Kode ${v.code} akan dipakai di checkout'),
                action: SnackBarAction(label: 'Pesan', onPressed: () => ref.read(shellTabProvider.notifier).go(1)),
              ));
          },
          style: FilledButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 14)),
          child: const Text('Pakai'),
        ),
      ]),
    );
  }
}


/// Daftar voucher aktif dalam bottom sheet (dipakai beranda dan menu Saya).
void showVouchersSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => Consumer(builder: (context, ref, _) {
      final vouchers = ref.watch(activeVouchersProvider);
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .7),
          child: AsyncView<List<VoucherView>>(
            value: vouchers,
            onRetry: () => ref.invalidate(activeVouchersProvider),
            builder: (list) => list.isEmpty
                ? const Padding(padding: EdgeInsets.all(32), child: Text('Belum ada voucher aktif saat ini.'))
                : ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
                    for (final v in list) Padding(padding: const EdgeInsets.only(bottom: 10), child: VoucherCard(v, wide: true)),
                  ]),
          ),
        ),
      );
    }),
  );
}
