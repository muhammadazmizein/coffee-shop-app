import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/format.dart';
import '../state/providers.dart';
import '../widgets/animated_number.dart';
import '../widgets/empty_state.dart';
import '../widgets/entrance.dart';
import '../widgets/illustration.dart';
import '../widgets/qty_stepper.dart';
import '../widgets/section_card.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  void _backToMenu(BuildContext context, WidgetRef ref) {
    ref.read(shellTabProvider.notifier).go(1);
    context.go('/');
  }

  void _remove(BuildContext context, WidgetRef ref, int i, CartLine l) {
    ref.read(cartProvider.notifier).setQty(i, 0);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('${l.product.name} dihapus'), action: SnackBarAction(label: 'Urungkan', onPressed: () => ref.read(cartProvider.notifier).insert(i, l))));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(cartProvider);
    final count = ref.watch(cartCountProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final outlet = ref.watch(selectedOutletProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keranjang'),
        actions: [
          if (lines.isNotEmpty)
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Kosongkan keranjang?'),
                    content: const Text('Semua menu di keranjang akan dihapus.'),
                    actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Kosongkan'))],
                  ),
                );
                if (ok == true) ref.read(cartProvider.notifier).clear();
              },
              child: const Text('Kosongkan'),
            ),
        ],
      ),
      body: lines.isEmpty
          ? EmptyState(icon: Icons.shopping_bag_outlined, title: 'Keranjangmu masih kosong', message: 'Pilih menu favoritmu, lalu kembali ke sini untuk checkout.', actionLabel: 'Lihat menu', onAction: () => _backToMenu(context, ref))
          : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
              if (outlet != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(color: const Color(0xFFE5F6F3), borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    const Icon(Icons.storefront_rounded, color: Color(0xFF0F766E)),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Pesanan dari ${outlet.name}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, color: kInk))),
                  ]),
                ),
              for (final (i, l) in lines.indexed)
                // Setiap baris masuk berundak; dihapus lewat tombol, baris menyusut dan memudar dulu; lewat geser, Dismissible yang menyusutkan.
                _RemovableLine(
                  key: ValueKey('line|${l.product.id}|${l.options.map((o) => o.id).join(',')}|${l.note}'),
                  delay: Duration(milliseconds: 60 * (i > 6 ? 0 : i)),
                  onRemoved: () => _remove(context, ref, i, l),
                  builder: (context, requestRemove) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Dismissible(
                      key: ValueKey('${l.product.id}|${l.options.map((o) => o.id).join(',')}|${l.note}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        decoration: BoxDecoration(color: const Color(0xFFC2563B), borderRadius: BorderRadius.circular(20)),
                        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
                      ),
                      onDismissed: (_) => _remove(context, ref, i, l),
                      child: _CartLineCard(index: i, onDelete: requestRemove),
                    ),
                  ),
                ),
              SectionCard(
                title: 'Ringkasan',
                child: Column(children: [
                  _AnimatedRow('Jumlah item', count, (v) => '$v'),
                  const Divider(height: 20, color: kCardBorder),
                  _AnimatedRow('Subtotal', subtotal, rupiah, bold: true),
                  const SizedBox(height: 4),
                  Text('Ongkir, diskon, dan poin dihitung di langkah berikutnya.', style: theme.textTheme.bodySmall?.copyWith(color: kMuted)),
                ]),
              ),
              const SizedBox(height: 10),
              Center(child: TextButton.icon(onPressed: () => _backToMenu(context, ref), icon: const Icon(Icons.add_circle_outline_rounded), label: const Text('Tambah menu lain'))),
            ]),
      bottomNavigationBar: lines.isEmpty
          ? null
          : FadeSlideIn(
              offset: const Offset(0, 48),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 14, offset: const Offset(0, -3))]),
                child: SafeArea(
                  child: FilledButton(
                    onPressed: () => context.push('/checkout'),
                    // FittedBox: label tidak boleh meluap di layar sempit; mengecil bila perlu.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Text('Checkout • '),
                        AnimatedNumber(value: subtotal, format: rupiah, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _CartLineCard extends ConsumerWidget {
  const _CartLineCard({required this.index, required this.onDelete});
  final int index;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(cartProvider);
    if (index >= lines.length) return const SizedBox.shrink();
    final l = lines[index];
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: kCardBorder)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ProductImage(l.product, size: 64, radius: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: kInk, height: 1.25)),
            if (l.options.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(l.options.map((o) => o.name).join(' • '), maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: kMuted))),
            if (l.note != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text('“${l.note}”', maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: kMuted))),
            const SizedBox(height: 10),
            Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 8, spacing: 8, children: [
              AnimatedNumber(value: l.total, format: rupiah, duration: const Duration(milliseconds: 400), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
              QtyStepper(
                compact: true,
                value: l.qty,
                onChanged: (v) => ref.read(cartProvider.notifier).setQty(index, v),
                onDelete: onDelete,
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

/// Baris ringkasan dengan angka yang menghitung menuju nilai baru.
class _AnimatedRow extends StatelessWidget {
  const _AnimatedRow(this.label, this.value, this.format, {this.bold = false});
  final String label;
  final int value;
  final String Function(int) format;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: bold ? 16 : 14, color: kInk);
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style.copyWith(fontWeight: FontWeight.w500, color: bold ? kInk : kMuted))),
      const SizedBox(width: 8),
      AnimatedNumber(value: value, format: format, style: style),
    ]);
  }
}

/// Satu baris keranjang: masuk berundak (sekali), dan bisa "dihapus" dengan animasi menyusut + memudar.
class _RemovableLine extends StatefulWidget {
  const _RemovableLine({super.key, required this.builder, required this.onRemoved, this.delay = Duration.zero});
  final Widget Function(BuildContext context, VoidCallback requestRemove) builder;
  final VoidCallback onRemoved;
  final Duration delay;

  @override
  State<_RemovableLine> createState() => _RemovableLineState();
}

class _RemovableLineState extends State<_RemovableLine> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 280), value: 1);
  bool _removing = false;

  void _request() {
    if (_removing) return;
    _removing = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      widget.onRemoved();
      return;
    }
    _c.reverse().whenComplete(() {
      if (mounted) widget.onRemoved();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      delay: widget.delay,
      child: SizeTransition(
        sizeFactor: CurvedAnimation(parent: _c, curve: Curves.easeInOut),
        alignment: Alignment.topCenter,
        child: FadeTransition(opacity: _c, child: widget.builder(context, _request)),
      ),
    );
  }
}
