import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../models/models.dart';
import '../state/providers.dart';
import '../widgets/animated_number.dart';
import '../widgets/animated_price_row.dart';
import '../widgets/entrance.dart';
import '../widgets/illustration.dart';
import '../widgets/product_card.dart' show textScale;
import '../widgets/section_card.dart';
import '../widgets/skeleton.dart';

class Quote {
  Quote(
    this.subtotal,
    this.discount,
    this.pointsUsed,
    this.pointDiscount,
    this.deliveryFee,
    this.total, {
    this.memberDiscount = 0,
    this.tierName,
    this.pointsToEarn = 0,
  });
  final int subtotal,
      discount,
      pointsUsed,
      pointDiscount,
      deliveryFee,
      total,
      memberDiscount,
      pointsToEarn;
  final String? tierName;
}

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _type = 'PICKUP';
  String? _addressId;
  String? _voucher; // kode yang sudah diterapkan
  bool _usePoints = false;
  final _voucherInput = TextEditingController();
  final _note = TextEditingController();
  Quote? _quote;
  String? _quoteError;
  bool _quoting = false;
  bool _submitting = false;
  int _quoteSeq = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Voucher yang dipilih dari beranda langsung terpasang; kode dikonsumsi sekali.
      final pending = ref.read(pendingVoucherProvider);
      if (pending != null) {
        _voucherInput.text = pending;
        _voucher = pending;
        ref.read(pendingVoucherProvider.notifier).set(null);
      }
      _refreshQuote();
    });
  }

  @override
  void dispose() {
    _voucherInput.dispose();
    _note.dispose();
    super.dispose();
  }

  Map<String, dynamic> _body() => {
    'outletId': ref.read(selectedOutletProvider)!.id,
    'type': _type,
    if (_type == 'DELIVERY' && _addressId != null) 'addressId': _addressId,
    if (_voucher != null) 'voucherCode': _voucher,
    // Server yang menentukan jumlah poin akhir (dibatasi saldo dan maks 50% belanja).
    if (_usePoints) 'usePoints': ref.read(authProvider).value?.points ?? 0,
    if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
    'items': ref.read(cartProvider).map((l) => l.toOrderJson()).toList(),
  };

  Future<void> _refreshQuote() async {
    if (_type == 'DELIVERY' && _addressId == null) {
      setState(() {
        _quote = null;
        _quoteError = null;
      });
      return;
    }
    final seq = ++_quoteSeq; // abaikan respons lama jika pengguna sudah mengubah pilihan lagi
    setState(() {
      _quoting = true;
      _quoteError = null;
    });
    try {
      final q = await ref
          .read(apiProvider)
          .post(
            '/orders/quote',
            _body(),
            (d) => Quote(
              d['subtotal'],
              d['discount'],
              d['pointsUsed'],
              d['pointDiscount'],
              d['deliveryFee'],
              d['total'],
              memberDiscount: d['memberDiscount'] ?? 0,
              tierName: d['tierName'],
              pointsToEarn: d['pointsToEarn'] ?? 0,
            ),
            auth: true,
          );
      if (seq == _quoteSeq && mounted) setState(() => _quote = q);
    } on ApiException catch (e) {
      if (seq == _quoteSeq && mounted) {
        setState(() {
          _quote = null;
          _quoteError = e.message;
          if (_voucher != null && e.message.toLowerCase().contains('voucher')) {
            _voucher = null;
          }
        });
      }
    } finally {
      if (seq == _quoteSeq && mounted) setState(() => _quoting = false);
    }
  }

  Future<void> _applyVoucher() async {
    final code = _voucherInput.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() => _voucher = code);
    await _refreshQuote();
  }

  Future<void> _pay() async {
    setState(() => _submitting = true);
    try {
      final order = await ref
          .read(apiProvider)
          .post(
            '/orders',
            _body(),
            (d) => d as Map<String, dynamic>,
            auth: true,
          );
      ref.read(cartProvider.notifier).clear();
      ref.invalidate(ordersProvider);
      ref.read(authProvider.notifier).refreshProfile();
      if (!mounted) return;
      final id = order['id'] as String;
      context.go('/');
      context.push('/orders/$id');
      context.push('/pay/$id');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _quoteError = e.message);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool _itemsOpen = false;

  void _setType(String t) {
    if (t == _type) return;
    setState(() => _type = t);
    _refreshQuote();
  }

  void _useVoucher(String code) {
    _voucherInput.text = code;
    setState(() => _voucher = code);
    _refreshQuote();
  }

  void _clearVoucher() {
    _voucherInput.clear();
    setState(() => _voucher = null);
    _refreshQuote();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outlet = ref.watch(selectedOutletProvider);
    final lines = ref.watch(cartProvider);
    final addresses = ref.watch(addressesProvider);
    final vouchers =
        ref.watch(activeVouchersProvider).value ?? const <VoucherView>[];
    final balance = ref.watch(authProvider).value?.points ?? 0;
    final radius = outlet?.deliveryRadiusKm ?? 0;
    final deliveryOn = radius > 0;
    final canPay = _quote != null && !_quoting && !_submitting;
    final cartSubtotal = ref.watch(cartSubtotalProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        // Setiap bagian masuk berundak sekali saat layar dibuka.
        children: _staggered([
          // 1. Metode pengambilan
          SectionCard(
            title: 'Metode pengambilan',
            icon: Icons.local_shipping_outlined,
            // IntrinsicHeight: kedua kartu sama tinggi tanpa memaksa tinggi tak terbatas di dalam kolom.
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _ModeCard(
                      icon: Icons.storefront_rounded,
                      title: 'Ambil di outlet',
                      subtitle: 'Tanpa ongkir',
                      selected: _type == 'PICKUP',
                      onTap: () => _setType('PICKUP'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ModeCard(
                      icon: Icons.delivery_dining_rounded,
                      title: 'Diantar',
                      subtitle: deliveryOn
                          ? 'Maks ${_km(radius)} km'
                          : 'Belum tersedia',
                      selected: _type == 'DELIVERY',
                      enabled: deliveryOn,
                      onTap: () => _setType('DELIVERY'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 2. Alamat
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            alignment: Alignment.topCenter,
            child: _type != 'DELIVERY'
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: SectionCard(
                      title: 'Alamat pengantaran',
                      icon: Icons.location_on_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Diantar kurir kami, maksimal ${_km(radius)} km dari outlet.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: kMuted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          addresses.when(
                            loading: () =>
                                const Column(children: [ListRowSkeleton()]),
                            error: (e, _) => Row(
                              children: [
                                Expanded(child: Text(e.toString())),
                                TextButton(
                                  onPressed: () =>
                                      ref.invalidate(addressesProvider),
                                  child: const Text('Coba lagi'),
                                ),
                              ],
                            ),
                            data: (list) => Column(
                              children: [
                                if (list.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      'Belum ada alamat. Tambahkan alamat untuk melihat ongkir.',
                                      style: TextStyle(color: kMuted),
                                    ),
                                  ),
                                for (final a in list)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _AddressTile(
                                      label: a.label,
                                      recipient: a.recipient,
                                      detail: a.detail,
                                      selected: a.id == _addressId,
                                      onTap: () {
                                        setState(() => _addressId = a.id);
                                        _refreshQuote();
                                      },
                                    ),
                                  ),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: () async {
                                      await context.push('/addresses/new');
                                      ref.invalidate(addressesProvider);
                                    },
                                    icon: const Icon(
                                      Icons.add_location_alt_outlined,
                                    ),
                                    label: const Text('Tambah alamat'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 14),
          // 3. Ringkasan pesanan (dapat diciutkan)
          SectionCard(
            title: 'Pesanan kamu',
            icon: Icons.receipt_long_outlined,
            trailing: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _itemsOpen = !_itemsOpen),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${lines.fold<int>(0, (n, l) => n + l.qty)} item',
                      style: const TextStyle(
                        color: kMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      _itemsOpen
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: kMuted,
                    ),
                  ],
                ),
              ),
            ),
            child: AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: _itemsOpen
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: SizedBox(
                height: 44,
                width: double.infinity,
                child: Row(
                  children: [
                    for (final l in lines.take(5))
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ProductImage(l.product, size: 40, radius: 12),
                      ),
                    if (lines.length > 5)
                      Text(
                        '+${lines.length - 5}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: kMuted,
                        ),
                      ),
                  ],
                ),
              ),
              secondChild: Column(
                children: [
                  for (final l in lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ProductImage(l.product, size: 44, radius: 12),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${l.qty}× ${l.product.name}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: kInk,
                                  ),
                                ),
                                if (l.options.isNotEmpty)
                                  Text(
                                    l.options.map((o) => o.name).join(' • '),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: kMuted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            rupiah(l.total),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: kInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          // 4. Voucher
          SectionCard(
            title: 'Voucher',
            icon: Icons.local_offer_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_voucher != null && _quoteError == null)
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2F6F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF0F766E)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF0F766E),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Kode $_voucher terpasang',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _clearVoucher,
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Lepas voucher',
                        ),
                      ],
                    ),
                  )
                else ...[
                  if (vouchers.isNotEmpty) ...[
                    SizedBox(
                      height: 40 * textScale(context),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: vouchers.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => ActionChip(
                          avatar: const Icon(
                            Icons.confirmation_number_outlined,
                            size: 18,
                            color: Color(0xFFC2563B),
                          ),
                          label: Text(
                            '${vouchers[i].code} • ${vouchers[i].headline}',
                          ),
                          onPressed: _quoting
                              ? null
                              : () => _useVoucher(vouchers[i].code),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _voucherInput,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            hintText: 'Punya kode voucher?',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _quoting ? null : _applyVoucher,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(84, 48),
                        ),
                        child: const Text('Pakai'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          // 5. Tukar poin
          SectionCard(
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF3D6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.stars_rounded,
                    color: Color(0xFFD99A1E),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tukar poin ($balance poin)',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: kInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _usePoints && _quote != null && _quote!.pointsUsed > 0
                            ? 'Pakai ${_quote!.pointsUsed} poin • setara ${rupiah(_quote!.pointDiscount)}'
                            : '1 poin = Rp100, maksimal 50% dari belanja',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: kMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _usePoints && balance > 0,
                  onChanged: balance == 0
                      ? null
                      : (v) {
                          setState(() => _usePoints = v);
                          _refreshQuote();
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // 6. Catatan
          SectionCard(
            title: 'Catatan untuk outlet',
            icon: Icons.edit_note_rounded,
            child: TextField(
              controller: _note,
              maxLength: 200,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Opsional',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 14),
          // 7. Rincian pembayaran
          SectionCard(
            title: 'Rincian pembayaran',
            icon: Icons.payments_outlined,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _quote == null
                  ? (_quoting
                        ? const Column(
                            key: ValueKey('skeleton'),
                            children: [
                              _SkeletonRow(),
                              _SkeletonRow(),
                              _SkeletonRow(),
                              SizedBox(height: 6),
                              _SkeletonRow(wide: true),
                            ],
                          )
                        : _type == 'DELIVERY' && _addressId == null
                        ? Row(
                            key: const ValueKey('noaddr'),
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: kMuted,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Pilih alamat untuk melihat ongkos kirim.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: kMuted,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : PriceRow(
                            'Subtotal',
                            rupiah(cartSubtotal),
                            key: const ValueKey('fallback'),
                          ))
                  : AnimatedOpacity(
                      key: const ValueKey('quote'),
                      duration: const Duration(milliseconds: 180),
                      opacity: _quoting ? .5 : 1,
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOut,
                        alignment: Alignment.topCenter,
                        child: Column(
                        children: [
                          AnimatedPriceRow('Subtotal', _quote!.subtotal),
                          if (_quote!.memberDiscount > 0)
                            AnimatedPriceRow('Diskon member ${_quote!.tierName ?? ''}', _quote!.memberDiscount, prefix: '-', color: const Color(0xFF0F766E)),
                          if (_quote!.discount > 0)
                            AnimatedPriceRow('Diskon voucher', _quote!.discount, prefix: '-', color: const Color(0xFF0F766E)),
                          if (_quote!.pointsUsed > 0)
                            AnimatedPriceRow('Tukar ${_quote!.pointsUsed} poin', _quote!.pointDiscount, prefix: '-', color: const Color(0xFF0F766E)),
                          if (_type == 'DELIVERY')
                            AnimatedPriceRow('Ongkos kirim', _quote!.deliveryFee),
                          const Divider(height: 20, color: kCardBorder),
                          AnimatedPriceRow('Total', _quote!.total, bold: true),
                          if (_quote!.pointsToEarn > 0)
                            Container(
                              margin: const EdgeInsets.only(top: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF6DE),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.stars_rounded,
                                    size: 18,
                                    color: Color(0xFFD99A1E),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Kamu akan dapat +${_quote!.pointsToEarn} poin',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF6B4A12),
                                          ),
                                    ),
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
          if (_quoteError != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFCE4DE),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFC2563B),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _quoteError!,
                      style: const TextStyle(
                        color: Color(0xFF8E2F1B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ]),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .08),
              blurRadius: 14,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: FilledButton(
            onPressed: canPay ? _pay : null,
            child: _submitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : (_quote == null
                      ? const Text('Bayar')
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Bayar • '),
                              AnimatedNumber(
                                value: _quote!.total,
                                format: rupiah,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
                              ),
                            ],
                          ),
                        )),
          ),
        ),
      ),
    );
  }

  List<Widget> _staggered(List<Widget> ws) => [
        for (final (i, w) in ws.indexed) FadeSlideIn(delay: Duration(milliseconds: 45 * (i > 9 ? 9 : i)), child: w),
      ];

  String _km(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toString().replaceAll('.', ',');
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({this.wide = false});
  final bool wide;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Skeleton(width: wide ? 70 : 110, height: wide ? 18 : 14),
        const Spacer(),
        Skeleton(width: wide ? 100 : 70, height: wide ? 18 : 14),
      ],
    ),
  );
}

/// Kartu pilihan besar (Ambil di outlet / Diantar).
class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });
  final IconData icon;
  final String title, subtitle;
  final bool selected, enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFF0F766E);
    final active = selected && enabled;
    return Opacity(
      opacity: enabled ? 1 : .5,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFE2F6F2) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active ? brand : const Color(0xFFCFE3E0),
            width: active ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 28, color: active ? brand : kMuted),
                const SizedBox(height: 10),
                Text(
                  title,
                  maxLines: 2,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: active ? brand : kInk,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 12.5, color: kMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddressTile extends StatelessWidget {
  const _AddressTile({
    required this.label,
    required this.recipient,
    required this.detail,
    required this.selected,
    required this.onTap,
  });
  final String label, recipient, detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFF0F766E);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE2F6F2) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? brand : const Color(0xFFCFE3E0),
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? brand : const Color(0xFF8AA09D),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$label • $recipient',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: kInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: kMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
