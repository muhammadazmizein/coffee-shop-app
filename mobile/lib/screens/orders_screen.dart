import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/format.dart';
import '../models/models.dart';
import '../state/providers.dart';
import '../widgets/empty_state.dart';
import '../widgets/entrance.dart';
import '../widgets/haptics.dart';
import '../widgets/illustration.dart';
import '../widgets/order_tracker.dart';
import '../widgets/skeleton.dart';
import '../widgets/status_chip.dart';

const _ink = Color(0xFF0B2E2B);
const _muted = Color(0xFF50706C);
const _border = Color(0xFFD5EBE8);
const _brand = Color(0xFF0F766E);

final _dateFmt = DateFormat('d MMM yyyy, HH:mm', 'id_ID');
final _timeFmt = DateFormat('HH:mm', 'id_ID');

const _activeStatuses = {'PENDING_PAYMENT', 'PAID', 'PREPARING', 'READY', 'ON_DELIVERY'};

/// Ilustrasi bawaan untuk sebuah item pesanan (item tidak punya objek Product, jadi dibuat sementara hanya untuk memilih gambar).
String _artFor(OrderItemView i) => productIllustration(Product(id: '', name: i.name, price: 0, groups: const []));

/// "Pesan lagi": isi keranjang dari pesanan lama lalu buka keranjang. Item yang sudah tidak tersedia dilewati dan diberi tahu.
Future<void> _reorderAndGo(BuildContext context, WidgetRef ref, OrderView o) async {
  try {
    final r = await reorder(ref, o);
    if (!context.mounted) return;
    final msg = r.added == 0
        ? 'Menu pesanan ini sedang tidak tersedia di outlet yang dipilih.'
        : '${r.added} item masuk keranjang${r.skipped > 0 ? ' (${r.skipped} item tidak tersedia dilewati)' : ''}';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
    if (r.added > 0) context.push('/cart');
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
  }
}

BoxDecoration _card() => BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: _border));

// ======================= DAFTAR PESANAN =======================

class OrdersTab extends ConsumerWidget {
  const OrdersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ordersProvider);
    final all = async.value;
    final active = all?.where((o) => _activeStatuses.contains(o.status)).toList() ?? const <OrderView>[];
    final history = all?.where((o) => !_activeStatuses.contains(o.status)).toList() ?? const <OrderView>[];

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pesanan'),
          bottom: TabBar(
            labelStyle: const TextStyle(fontWeight: FontWeight.w800),
            tabs: [Tab(text: active.isEmpty ? 'Aktif' : 'Aktif (${active.length})'), const Tab(text: 'Riwayat')],
          ),
        ),
        body: all == null
            ? (async.hasError
                ? EmptyState(icon: Icons.cloud_off_rounded, title: 'Gagal memuat pesanan', message: async.error.toString(), actionLabel: 'Coba lagi', onAction: () => ref.invalidate(ordersProvider))
                : const _OrdersSkeleton())
            : TabBarView(children: [
                _OrdersList(orders: active, empty: true),
                _OrdersList(orders: history, empty: false),
              ]),
      ),
    );
  }
}

class _OrdersSkeleton extends StatelessWidget {
  const _OrdersSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), physics: const NeverScrollableScrollPhysics(), children: [
      for (var i = 0; i < 3; i++)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: _card(),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ListRowSkeleton(),
            SizedBox(height: 8),
            Skeleton(height: 12),
            SizedBox(height: 14),
            Row(children: [Skeleton(width: 90, height: 20), Spacer(), Skeleton(width: 120, height: 40, radius: 14)]),
          ]),
        ),
    ]);
  }
}

class _OrdersList extends ConsumerStatefulWidget {
  const _OrdersList({required this.orders, required this.empty});
  final List<OrderView> orders;
  final bool empty; // true = tab Aktif (teks dan aksi kosongnya berbeda)

  @override
  ConsumerState<_OrdersList> createState() => _OrdersListState();
}

class _OrdersListState extends ConsumerState<_OrdersList> {
  String? _busy;

  Future<void> _again(OrderView o) async {
    setState(() => _busy = o.id);
    await _reorderAndGo(context, ref, o);
    if (mounted) setState(() => _busy = null);
  }

  @override
  Widget build(BuildContext context) {
    final isActiveTab = widget.empty;
    return RefreshIndicator(
      onRefresh: () => ref.refresh(ordersProvider.future),
      child: widget.orders.isEmpty
          ? LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight),
                  child: isActiveTab
                      ? EmptyState(
                          illustration: 'product_latte',
                          title: 'Belum ada pesanan aktif',
                          message: 'Pesananmu yang sedang diproses akan muncul di sini, lengkap dengan pelacaknya.',
                          actionLabel: 'Pesan sekarang',
                          onAction: () {
                            ref.read(shellTabProvider.notifier).go(1);
                            context.go('/');
                          },
                        )
                      : const EmptyState(icon: Icons.receipt_long_outlined, title: 'Belum ada riwayat', message: 'Pesanan yang sudah selesai atau dibatalkan akan tersimpan di sini.'),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: widget.orders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              // Kartu masuk berundak (hanya delapan pertama, supaya daftar panjang tidak terasa lambat).
              itemBuilder: (_, i) => FadeSlideIn(
                delay: Duration(milliseconds: 70 * (i > 7 ? 0 : i)),
                child: _OrderCard(order: widget.orders[i], busy: _busy == widget.orders[i].id, onAgain: () => _again(widget.orders[i])),
              ),
            ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.busy, required this.onAgain});
  final OrderView order;
  final bool busy;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final theme = Theme.of(context);
    final first = o.items.isEmpty ? null : o.items.first;
    final pending = o.status == 'PENDING_PAYMENT';
    final deadline = o.payment?.expiresAt;

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: _border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/orders/${o.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Stack(clipBehavior: Clip.none, children: [
                ClipOval(child: SizedBox(width: 56, height: 56, child: first == null ? const ColoredBox(color: Color(0xFFE5F6F3)) : Illustration(_artFor(first), width: 56, height: 56))),
                if (o.items.length > 1)
                  Positioned(
                    right: -6,
                    bottom: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: _brand, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white, width: 2)),
                      child: Text('+${o.items.length - 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ),
              ]),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(o.outletName ?? 'Outlet', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: _ink)),
                  const SizedBox(height: 2),
                  Text(_dateFmt.format(o.createdAt), style: theme.textTheme.bodySmall?.copyWith(color: _muted)),
                  const SizedBox(height: 6),
                  Text(o.items.map((e) => '${e.qty}x ${e.name}').join(', '), maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(height: 1.3)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    StatusChip(status: o.status, type: o.type),
                    _TypeChip(type: o.type),
                  ]),
                ]),
              ),
            ]),
            if (pending) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(color: const Color(0xFFFFF4DC), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.schedule_rounded, size: 18, color: Color(0xFF8A5A00)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(deadline != null && o.payment?.isPending == true ? 'Bayar sebelum ${_timeFmt.format(deadline)}' : 'Selesaikan pembayaran agar pesanan diproses', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF6B4A12)))),
                ]),
              ),
            ],
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: _border)),
            // Wrap (bukan Row) agar tombol turun ke baris bawah bila layar sempit atau font besar.
            Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 10, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text('Total', style: theme.textTheme.bodySmall?.copyWith(color: _muted)),
                  Text(rupiah(o.total), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: _ink)),
                ]),
              if (pending)
                FilledButton(
                  onPressed: () => context.push('/pay/${o.id}'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 20)),
                  child: const Text('Bayar sekarang'),
                )
              else if (o.status == 'COMPLETED')
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () {
                          tapHaptic();
                          onAgain();
                        },
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44), side: const BorderSide(color: _brand, width: 1.5), foregroundColor: _brand),
                  icon: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.replay_rounded, size: 18),
                  label: const Text('Pesan lagi'),
                )
              else if (_activeStatuses.contains(o.status))
                TextButton.icon(onPressed: () => context.push('/orders/${o.id}'), icon: const Icon(Icons.arrow_forward_rounded, size: 18), label: const Text('Lacak')),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    final pickup = type == 'PICKUP';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: const Color(0xFFEEF4F3), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(pickup ? Icons.storefront_rounded : Icons.delivery_dining_rounded, size: 15, color: _muted),
        const SizedBox(width: 5),
        Text(pickup ? 'Ambil' : 'Antar', style: const TextStyle(color: _muted, fontWeight: FontWeight.w700, fontSize: 12.5)),
      ]),
    );
  }
}

// ======================= DETAIL PESANAN =======================

String _helperText(OrderView o) => switch (o.status) {
      'PENDING_PAYMENT' => 'Selesaikan pembayaran agar pesananmu mulai diproses.',
      'PAID' => 'Pembayaran diterima. Barista akan segera membuat pesananmu.',
      'PREPARING' => 'Barista sedang membuat pesananmu.',
      'READY' => o.type == 'PICKUP' ? 'Pesananmu sudah siap. Tunjukkan kode pesanan di bawah ke kasir ${o.outletName ?? 'outlet'}.' : 'Pesananmu sudah siap dan menunggu kurir.',
      'ON_DELIVERY' => 'Kurir sedang mengantar pesananmu.',
      'COMPLETED' => 'Terima kasih sudah memesan. Semoga kamu suka!',
      'CANCELLED' => 'Pesanan ini dibatalkan. Kalau kamu sudah membayar, hubungi outlet untuk pengembalian dana.',
      'EXPIRED' => 'Waktu pembayaran habis. Kamu bisa memesan lagi kapan saja.',
      _ => '',
    };

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  Timer? _poll;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Polling ringan selama pesanan belum selesai/batal; berhenti otomatis saat layar ditutup.
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      final status = ref.read(orderProvider(widget.id)).value?.status;
      if (status == null || !const {'COMPLETED', 'CANCELLED', 'EXPIRED'}.contains(status)) {
        ref.invalidate(orderProvider(widget.id));
        ref.invalidate(ordersProvider);
        if (status == 'PENDING_PAYMENT') ref.read(authProvider.notifier).refreshProfile();
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _again(OrderView o) async {
    setState(() => _busy = true);
    await _reorderAndGo(context, ref, o);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    // Pakai .value (bukan .when) agar data lama tetap tampil saat polling memuat ulang, tanpa berkedip.
    final async = ref.watch(orderProvider(widget.id));
    final o = async.value;

    Widget? bottom;
    if (o != null && o.awaitingPayment) {
      bottom = FilledButton.icon(onPressed: () => context.push('/pay/${o.id}'), icon: const Icon(Icons.payments_rounded), label: Text(o.payment?.isPending == true ? 'Lanjutkan pembayaran' : 'Bayar sekarang'));
    } else if (o != null && o.status == 'COMPLETED') {
      bottom = FilledButton.icon(
        onPressed: _busy
            ? null
            : () {
                tapHaptic();
                _again(o);
              },
        icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.replay_rounded),
        label: const Text('Pesan lagi'),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Detail pesanan')),
      body: o == null
          ? (async.hasError
              ? EmptyState(icon: Icons.cloud_off_rounded, title: 'Gagal memuat pesanan', message: async.error.toString(), actionLabel: 'Coba lagi', onAction: () => ref.invalidate(orderProvider(widget.id)))
              : const _DetailSkeleton())
          : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
              _StatusCard(order: o),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
                decoration: _card(),
                child: OrderTracker(status: o.status, type: o.type, eventStatuses: [for (final e in o.events) e.status]),
              ),
              if (o.courierName != null) ...[const SizedBox(height: 14), _CourierCard(name: o.courierName!, phone: o.courierPhone)],
              const SizedBox(height: 14),
              _ItemsCard(order: o),
              const SizedBox(height: 14),
              _PriceCard(order: o),
              if (o.events.isNotEmpty) ...[const SizedBox(height: 14), _TimelineCard(order: o)],
            ]),
      bottomNavigationBar: bottom == null
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 12, offset: const Offset(0, -2))]),
                child: bottom,
              ),
            ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), physics: const NeverScrollableScrollPhysics(), children: const [
      Skeleton(height: 150, radius: 24),
      SizedBox(height: 14),
      Skeleton(height: 96, radius: 22),
      SizedBox(height: 14),
      Skeleton(height: 170, radius: 22),
      SizedBox(height: 14),
      Skeleton(height: 130, radius: 22),
    ]);
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.order});
  final OrderView order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final s = statusStyle(o.status);
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [s.color, Color.lerp(s.color, Colors.black, .38)!]),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .2), shape: BoxShape.circle),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              switchInCurve: Curves.elasticOut,
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: Icon(s.icon, key: ValueKey(o.status), color: Colors.white, size: 30),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(statusLabel(o.status, o.type), key: ValueKey(o.status), style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 4),
              Text(_helperText(o), style: TextStyle(color: Colors.white.withValues(alpha: .88), fontSize: 13.5, height: 1.35)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: .18), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Kode pesanan', style: TextStyle(color: Colors.white.withValues(alpha: .7), fontSize: 12)),
                Text(o.code, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: .6)),
              ]),
            ),
            IconButton(
              tooltip: 'Salin kode',
              icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 20),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: o.code));
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(const SnackBar(content: Text('Kode pesanan disalin'), duration: Duration(seconds: 1)));
                }
              },
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _OnColorChip(icon: o.type == 'PICKUP' ? Icons.storefront_rounded : Icons.delivery_dining_rounded, text: o.type == 'PICKUP' ? 'Ambil di ${o.outletName ?? 'outlet'}' : 'Diantar dari ${o.outletName ?? 'outlet'}'),
          _OnColorChip(icon: Icons.event_rounded, text: _dateFmt.format(o.createdAt)),
        ]),
      ]),
    );
  }
}

class _OnColorChip extends StatelessWidget {
  const _OnColorChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 68),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: Colors.white),
        const SizedBox(width: 6),
        Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5))),
      ]),
    );
  }
}

class _CourierCard extends StatelessWidget {
  const _CourierCard({required this.name, required this.phone});
  final String name;
  final String? phone;

  Future<void> _call(BuildContext context) async {
    var ok = false;
    try {
      ok = await launchUrl(Uri(scheme: 'tel', path: '+$phone'));
    } catch (_) {}
    if (!ok && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak bisa membuka aplikasi telepon.')));
  }

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _card(),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF2DBDB0), Color(0xFF0B5F58)])),
          child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Kurir kamu', style: TextStyle(color: _muted, fontSize: 12)),
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _ink)),
            if (phone != null) Text('+$phone', style: const TextStyle(color: _muted, fontSize: 13)),
          ]),
        ),
        if (phone != null)
          FilledButton.icon(
            onPressed: () => _call(context),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 14)),
            icon: const Icon(Icons.call_rounded, size: 18),
            label: const Text('Telepon'),
          ),
      ]),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.order});
  final OrderView order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: _card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Pesananmu', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        for (final i in order.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipOval(child: Illustration(_artFor(i), width: 52, height: 52)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(i.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _ink)),
                  if (i.options.isNotEmpty) Text(i.options.join(', '), maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: _muted)),
                  if (i.note != null && i.note!.isNotEmpty) Text('Catatan: ${i.note}', maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: _muted)),
                  const SizedBox(height: 2),
                  Text('${i.qty} × ${rupiah(i.unitPrice)}', style: theme.textTheme.bodySmall?.copyWith(color: _muted)),
                ]),
              ),
              const SizedBox(width: 10),
              Text(rupiah(i.unitPrice * i.qty), style: const TextStyle(fontWeight: FontWeight.w800, color: _ink)),
            ]),
          ),
      ]),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.order});
  final OrderView order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final theme = Theme.of(context);
    final pointDiscount = o.subtotal - o.memberDiscount - o.discount + o.deliveryFee - o.total;

    Widget row(String l, String v, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(l, style: TextStyle(color: color ?? _muted))),
            const SizedBox(width: 12),
            Text(v, style: TextStyle(fontWeight: FontWeight.w600, color: color ?? _ink)),
          ]),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Rincian pembayaran', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        row('Subtotal', rupiah(o.subtotal)),
        if (o.memberDiscount > 0) row('Diskon member${o.tierName != null ? ' ${o.tierName}' : ''}', '-${rupiah(o.memberDiscount)}', color: _brand),
        if (o.discount > 0) row('Diskon voucher', '-${rupiah(o.discount)}', color: _brand),
        if (o.pointsUsed > 0) row('Tukar ${o.pointsUsed} poin', '-${rupiah(pointDiscount)}', color: _brand),
        if (o.deliveryFee > 0) row('Ongkos kirim', rupiah(o.deliveryFee)),
        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: _border)),
        Row(children: [
          Text('Total', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const Spacer(),
          Text(rupiah(o.total), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: _ink)),
        ]),
      ]),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.order});
  final OrderView order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final events = order.events;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: _card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Riwayat pesanan', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        for (final (idx, e) in events.indexed)
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Column(children: [
                Container(width: 30, height: 30, decoration: BoxDecoration(color: statusStyle(e.status).color.withValues(alpha: .14), shape: BoxShape.circle), child: Icon(statusStyle(e.status).icon, size: 17, color: statusStyle(e.status).color)),
                if (idx != events.length - 1) Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 3), color: _border)),
              ]),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: idx == events.length - 1 ? 0 : 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(statusLabel(e.status, order.type), style: const TextStyle(fontWeight: FontWeight.w700, color: _ink)),
                    Text(_dateFmt.format(e.at), style: theme.textTheme.bodySmall?.copyWith(color: _muted)),
                  ]),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}
