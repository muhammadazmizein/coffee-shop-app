import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../models/models.dart';
import '../state/providers.dart';
import '../widgets/animated_number.dart';
import '../widgets/async_view.dart';
import '../widgets/entrance.dart';
import '../widgets/particle_burst.dart';
import '../widgets/pulse.dart';

const _espresso = Color(0xFF0B2E2B);

/// Tampilan tiap metode (warna merek hanya sebagai penanda, bukan logo resmi).
class _Look {
  const _Look(this.color, this.badge, this.hint);
  final Color color;
  final String badge, hint;
}

const _looks = {
  'qris': _Look(
    Color(0xFFD32F2F),
    'QR',
    'Scan dengan e-wallet atau m-banking apa pun',
  ),
  'gopay': _Look(Color(0xFF00A94F), 'GP', 'Scan QR atau buka aplikasi GoPay'),
  'shopeepay': _Look(
    Color(0xFFEE4D2D),
    'SP',
    'Buka aplikasi Shopee untuk membayar',
  ),
  'ovo': _Look(Color(0xFF4C2A86), 'OVO', 'Bayar lewat aplikasi OVO'),
  'bca_va': _Look(
    Color(0xFF0060AF),
    'BCA',
    'Transfer ke nomor virtual account',
  ),
  'bni_va': _Look(
    Color(0xFFE8631A),
    'BNI',
    'Transfer ke nomor virtual account',
  ),
  'bri_va': _Look(
    Color(0xFF00529C),
    'BRI',
    'Transfer ke nomor virtual account',
  ),
  'mandiri_va': _Look(
    Color(0xFF003D79),
    'MDR',
    'Bayar lewat kode perusahaan dan kode bayar',
  ),
  'permata_va': _Look(
    Color(0xFF5BA32B),
    'PMT',
    'Transfer ke nomor virtual account',
  ),
};

_Look _lookOf(String key) => _looks[key] ?? const _Look(_espresso, '•', '');

String _bankName(String? b) => switch (b) {
  'bca' => 'BCA',
  'bni' => 'BNI',
  'bri' => 'BRI',
  'permata' => 'Permata',
  _ => (b ?? '').toUpperCase(),
};

/// 125 detik -> "02:05"
String mmss(Duration d) {
  final s = d.isNegative ? 0 : d.inSeconds;
  return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

class PayScreen extends ConsumerStatefulWidget {
  const PayScreen({super.key, required this.orderId});
  final String orderId;

  @override
  ConsumerState<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends ConsumerState<PayScreen> {
  Timer? _poll;
  Timer? _tick;
  PaymentView? _local;
  bool _choosing = false;
  String? _busy;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(lastPayOrderProvider.notifier).set(widget.orderId),
    );
    // Server menyinkronkan status ke Midtrans tiap kali pesanan dibaca, jadi polling ringan sudah cukup.
    _poll = Timer.periodic(const Duration(seconds: 3), (_) {
      final status = ref.read(orderProvider(widget.orderId)).value?.status;
      if (mounted && (status == null || status == 'PENDING_PAYMENT')) {
        ref.invalidate(orderProvider(widget.orderId));
      }
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  /// OVO memakai push ke aplikasi OVO, jadi butuh nomor akun OVO (bisa berbeda dari nomor login).
  Future<String?> _askOvoPhone() {
    final user = ref.read(authProvider).value;
    final controller = TextEditingController(
      text: user == null ? '' : '0${user.phone.replaceFirst('62', '')}',
    );
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nomor akun OVO'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Permintaan bayar akan dikirim ke aplikasi OVO pada nomor ini. Konfirmasi dalam 1 menit.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nomor HP OVO',
                hintText: '0812 3456 7890',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Kirim permintaan'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _choose(PayMethod m) async {
    String? phone;
    if (m.key == 'ovo') {
      phone = await _askOvoPhone();
      if (phone == null || phone.isEmpty || !mounted) return;
    }
    setState(() => _busy = m.key);
    try {
      final pv = await ref
          .read(apiProvider)
          .post(
            '/orders/${widget.orderId}/pay',
            {'method': m.key, 'phone': ?phone},
            (d) => PaymentView.fromJson(
              Map<String, dynamic>.from(d as Map),
              orderId: widget.orderId,
            ),
            auth: true,
          );
      if (!mounted) return;
      setState(() {
        _local = pv;
        _choosing = false;
      });
      ref.invalidate(orderProvider(widget.orderId));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _open(String url) async {
    var ok = false;
    try {
      ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aplikasinya tidak ditemukan di HP ini. Coba pakai metode lain.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(orderProvider(widget.orderId), (prev, next) {
      final was = prev?.value?.status, now = next.value?.status;
      if (was == 'PENDING_PAYMENT' && now != null && now != 'PENDING_PAYMENT') {
        HapticFeedback.mediumImpact();
        ref.invalidate(ordersProvider);
        ref.invalidate(membershipProvider);
        ref.invalidate(pointsHistoryProvider);
        ref.read(authProvider.notifier).refreshProfile();
      }
    });

    final async = ref.watch(orderProvider(widget.orderId));
    final order = async.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran')),
      body: order == null
          ? (async.hasError
                ? AsyncView<OrderView>(
                    value: async,
                    builder: (_) => const SizedBox(),
                    onRetry: () =>
                        ref.invalidate(orderProvider(widget.orderId)),
                  )
                : const Center(child: CircularProgressIndicator()))
          : _body(order),
    );
  }

  Widget _body(OrderView order) {
    if (order.status != 'PENDING_PAYMENT') {
      final ok = !{'CANCELLED', 'EXPIRED'}.contains(order.status);
      return _Result(order: order, success: ok);
    }
    final payment = _local ?? order.payment;
    final expired =
        payment != null &&
        (!payment.isPending ||
            (payment.expiresAt != null && payment.expiresAt!.isBefore(_now)));
    final showChooser = _choosing || payment == null || expired;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _Summary(
          order: order,
          payment: showChooser ? null : payment,
          now: _now,
        ),
        const SizedBox(height: 20),
        // Perpindahan pilih-metode <-> petunjuk bayar dibuat halus (memudar + geser ringan).
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, .04),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey(showChooser ? 'chooser' : 'instr-${payment.method}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showChooser) ...[
                  if (expired && !_choosing)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1D6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.schedule, color: Color(0xFFB26A00)),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Tagihan sebelumnya sudah tidak berlaku. Pilih metode pembayaran lagi.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  _Chooser(
                    busy: _busy,
                    onPick: _choose,
                    current: _choosing ? payment?.method : null,
                  ),
                ] else ...[
                  const _WaitingBanner(),
                  const SizedBox(height: 16),
                  _Instructions(payment: payment, onOpen: _open),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _choosing = true),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      side: const BorderSide(color: _cardBorder, width: 1.5),
                      foregroundColor: _espresso,
                    ),
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Ganti metode pembayaran'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------- Ringkasan ----------

class _Summary extends StatelessWidget {
  const _Summary({
    required this.order,
    required this.payment,
    required this.now,
  });
  final OrderView order;
  final PaymentView? payment;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final left = payment?.expiresAt?.difference(now);
    final urgent = left != null && left.inSeconds < 300;
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF12948A), Color(0xFF063B38)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -36,
              top: -36,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .06),
                ),
              ),
            ),
            Positioned(
              right: 40,
              bottom: -64,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .05),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Total pembayaran',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .72),
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      if (left != null)
                        // Di bawah 5 menit pil memerah dan berdenyut agar tenggat terasa mendesak.
                        Pulse(
                          active: urgent && !left.isNegative,
                          maxScale: 1.08,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: urgent
                                  ? const Color(0xFFE0573A)
                                  : Colors.white.withValues(alpha: .16),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.timer_outlined,
                                  size: 15,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  left.isNegative ? 'Habis' : mmss(left),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      rupiah(order.total),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 16,
                        color: Colors.white.withValues(alpha: .7),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Pesanan ${order.code}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .7),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Penanda "menunggu pembayaran" dengan titik berdenyut.
class _WaitingBanner extends StatefulWidget {
  const _WaitingBanner();

  @override
  State<_WaitingBanner> createState() => _WaitingBannerState();
}

class _WaitingBannerState extends State<_WaitingBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4DC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          FadeTransition(
            opacity: Tween(begin: .35, end: 1.0).animate(_c),
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFFE59A1E),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Menunggu pembayaran. Halaman ini berubah otomatis setelah pembayaran diterima.',
              style: TextStyle(
                fontSize: 13,
                height: 1.3,
                color: Color(0xFF6B4A12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Pilih metode ----------

class _Chooser extends ConsumerWidget {
  const _Chooser({required this.busy, required this.onPick, this.current});
  final String? busy, current;
  final void Function(PayMethod) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methods = ref.watch(payMethodsProvider);
    return AsyncView<List<PayMethod>>(
      value: methods,
      onRetry: () => ref.invalidate(payMethodsProvider),
      builder: (list) {
        Widget group(String title, Iterable<PayMethod> items) {
          if (items.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 0, 10),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              for (final m in items)
                _MethodTile(
                  method: m,
                  loading: busy == m.key,
                  disabled: busy != null,
                  selected: current == m.key,
                  onTap: () => onPick(m),
                ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            group('QRIS & E-Wallet', list.where((m) => m.group != 'va')),
            const SizedBox(height: 8),
            group('Virtual Account', list.where((m) => m.group == 'va')),
          ],
        );
      },
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.method,
    required this.loading,
    required this.disabled,
    required this.selected,
    required this.onTap,
  });
  final PayMethod method;
  final bool loading, disabled, selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final look = _lookOf(method.key);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: disabled ? null : onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? look.color : const Color(0xFFD5EBE8),
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: look.color,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    look.badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        method.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        look.hint,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Petunjuk bayar ----------

const _cardBorder = Color(0xFFD5EBE8);

Future<void> _copy(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Tersalin'),
          duration: Duration(seconds: 1),
        ),
      );
  }
}

/// Kartu putih dengan pita judul berwarna di atasnya.
class _TicketCard extends StatelessWidget {
  const _TicketCard({
    required this.look,
    required this.title,
    required this.child,
  });
  final _Look look;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  look.color,
                  Color.lerp(look.color, Colors.black, .28)!,
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    look.badge,
                    style: TextStyle(
                      color: look.color,
                      fontWeight: FontWeight.w900,
                      fontSize: look.badge.length > 2 ? 11 : 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }
}

/// Angka panjang (nomor VA) dipecah 4 digit agar mudah dibaca dan dicocokkan.
class _GroupedNumber extends StatelessWidget {
  const _GroupedNumber(this.value);
  final String value;

  @override
  Widget build(BuildContext context) {
    final chunks = [
      for (var i = 0; i < value.length; i += 4)
        value.substring(i, i + 4 > value.length ? value.length : i + 4),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (final c in chunks)
          Text(
            c,
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              height: 1.25,
              color: _espresso,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
      ],
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.value, this.copyValue});
  final String label, value;
  final String? copyValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodySmall),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _espresso,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => _copy(context, copyValue ?? value),
          child: const Text('Salin'),
        ),
      ],
    );
  }
}

class _Instructions extends StatelessWidget {
  const _Instructions({required this.payment, required this.onOpen});
  final PaymentView payment;
  final Future<void> Function(String url) onOpen;

  @override
  Widget build(BuildContext context) {
    final look = _lookOf(payment.method);
    final theme = Theme.of(context);
    final divider = Divider(
      height: 28,
      color: _cardBorder.withValues(alpha: .9),
    );
    final children = <Widget>[];

    if (payment.vaNumber != null) {
      children.add(
        _TicketCard(
          look: look,
          title: '${_bankName(payment.vaBank)} Virtual Account',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nomor Virtual Account', style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              _GroupedNumber(payment.vaNumber!),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _copy(context, payment.vaNumber!),
                style: FilledButton.styleFrom(backgroundColor: look.color),
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Salin nomor VA'),
              ),
              divider,
              _FieldRow(
                label: 'Jumlah transfer',
                value: rupiah(payment.amount),
                copyValue: payment.amount.toString(),
              ),
            ],
          ),
        ),
      );
    } else if (payment.billKey != null) {
      children.add(
        _TicketCard(
          look: look,
          title: 'Mandiri Bill Payment',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldRow(
                label: 'Kode perusahaan',
                value: payment.billerCode ?? '-',
              ),
              divider,
              Text('Kode bayar', style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              _GroupedNumber(payment.billKey!),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _copy(context, payment.billKey!),
                style: FilledButton.styleFrom(backgroundColor: look.color),
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Salin kode bayar'),
              ),
              divider,
              _FieldRow(
                label: 'Jumlah transfer',
                value: rupiah(payment.amount),
                copyValue: payment.amount.toString(),
              ),
            ],
          ),
        ),
      );
    } else if (payment.qrString != null || payment.qrImageUrl != null) {
      children.add(
        _TicketCard(
          look: look,
          title: payment.method == 'gopay'
              ? 'Bayar dengan GoPay'
              : 'Bayar dengan QRIS',
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _cardBorder, width: 1.5),
                ),
                child: payment.qrString != null
                    ? QrImageView(
                        data: payment.qrString!,
                        size: 220,
                        backgroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                      )
                    : Image.network(
                        payment.qrImageUrl!,
                        width: 220,
                        height: 220,
                        fit: BoxFit.contain,
                        loadingBuilder: (_, child, p) => p == null
                            ? child
                            : const SizedBox(
                                width: 220,
                                height: 220,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                        errorBuilder: (_, _, _) => const SizedBox(
                          width: 220,
                          height: 220,
                          child: Center(
                            child: Text(
                              'QR gagal dimuat.\nGanti metode atau coba lagi.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 14),
              Text(
                rupiah(payment.amount),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: _espresso,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Scan dengan aplikasi e-wallet atau m-banking',
                style: theme.textTheme.bodySmall,
              ),
              if (payment.deeplinkUrl != null) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => onOpen(payment.deeplinkUrl!),
                  style: FilledButton.styleFrom(backgroundColor: look.color),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Buka aplikasi GoPay'),
                ),
              ],
            ],
          ),
        ),
      );
    } else if (payment.method == 'ovo') {
      children.add(
        _TicketCard(
          look: look,
          title: 'Bayar dengan OVO',
          child: Column(
            children: [
              const Icon(
                Icons.phone_android,
                size: 44,
                color: Color(0xFF4C2A86),
              ),
              const SizedBox(height: 10),
              Text(
                rupiah(payment.amount),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: _espresso,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Permintaan pembayaran dikirim ke aplikasi OVO${payment.ovoPhone != null ? ' pada nomor ${payment.ovoPhone}' : ''}. Buka notifikasinya dan konfirmasi dalam 1 menit.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
            ],
          ),
        ),
      );
    } else if (payment.deeplinkUrl != null) {
      children.add(
        _TicketCard(
          look: look,
          title: 'Bayar dengan ShopeePay',
          child: Column(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 44,
                color: look.color,
              ),
              const SizedBox(height: 10),
              Text(
                rupiah(payment.amount),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: _espresso,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ketuk tombol di bawah untuk membuka aplikasi Shopee, lalu konfirmasi pembayaran.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => onOpen(payment.deeplinkUrl!),
                style: FilledButton.styleFrom(backgroundColor: look.color),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Buka ShopeePay'),
              ),
            ],
          ),
        ),
      );
    }

    children.add(const SizedBox(height: 16));
    children.add(
      Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cara membayar',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            for (final (i, step) in _steps(payment).indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: look.color.withValues(alpha: .12),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: look.color,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          step,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  List<String> _steps(PaymentView p) {
    switch (p.method) {
      case 'qris':
        return [
          'Buka aplikasi e-wallet atau m-banking pilihanmu.',
          'Pilih Scan atau Bayar dengan QR.',
          'Arahkan kamera ke kode QR di atas.',
          'Periksa nominal, lalu konfirmasi pembayaran.',
        ];
      case 'gopay':
        return [
          'Di HP ini: ketuk Buka aplikasi GoPay, lalu konfirmasi pembayaran.',
          'Atau dari HP lain: scan kode QR di atas lewat aplikasi GoPay.',
          'Periksa nominal, lalu konfirmasi dengan PIN.',
        ];
      case 'shopeepay':
        return [
          'Ketuk Buka ShopeePay, aplikasi Shopee akan terbuka.',
          'Periksa nominal pembayaran.',
          'Konfirmasi dengan PIN ShopeePay, lalu kembali ke aplikasi ini.',
        ];
      case 'ovo':
        return [
          'Buka notifikasi permintaan pembayaran di aplikasi OVO.',
          'Periksa nominal, lalu konfirmasi dengan PIN OVO dalam 1 menit.',
          'Jika waktunya habis, pilih Ganti metode pembayaran lalu kirim permintaan lagi.',
        ];
      case 'mandiri_va':
        return [
          'Buka Livin\' by Mandiri atau ATM Mandiri.',
          'Pilih Bayar, lalu Multipayment.',
          'Masukkan kode perusahaan dan kode bayar di atas.',
          'Periksa nominal, lalu konfirmasi pembayaran.',
        ];
      default:
        return [
          'Buka m-banking atau ATM ${_bankName(p.vaBank)}.',
          'Pilih Transfer, lalu Virtual Account.',
          'Masukkan nomor Virtual Account di atas.',
          'Periksa nominal dan nama penerima, lalu konfirmasi.',
        ];
    }
  }
}

// ---------- Hasil ----------

class _Result extends StatefulWidget {
  const _Result({required this.order, required this.success});
  final OrderView order;
  final bool success;

  @override
  State<_Result> createState() => _ResultState();
}

class _ResultState extends State<_Result> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Animation<double> _iv(double a, double b, Curve curve) => CurvedAnimation(
    parent: _c,
    curve: Interval(a, b, curve: curve),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ok = widget.success;
    final color = ok ? const Color(0xFF2F7A3E) : const Color(0xFFC2563B);
    final pop = _iv(0, .45, Curves.elasticOut);
    final draw = _iv(.28, .62, Curves.easeOutCubic);
    final ring = _iv(.3, 1, Curves.easeOut);
    final content = Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _c,
              builder: (_, _) => SizedBox(
                width: 150,
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // riak yang melebar lalu hilang, sekali saja
                    Opacity(
                      opacity: ok ? (1 - ring.value).clamp(0.0, 1.0) * .5 : 0,
                      child: Transform.scale(
                        scale: .75 + .6 * ring.value,
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: color, width: 3),
                          ),
                        ),
                      ),
                    ),
                    Transform.scale(
                      scale: pop.value.clamp(0.0, 1.4),
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: .12),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                            child: ok
                                ? CustomPaint(
                                    painter: _CheckPainter(
                                      draw.value,
                                      Colors.white,
                                    ),
                                  )
                                : Transform.scale(
                                    scale: draw.value,
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.white,
                                      size: 48,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            FadeSlideIn(
              delay: const Duration(milliseconds: 450),
              child: Text(
                ok
                    ? 'Pembayaran berhasil'
                    : (widget.order.status == 'EXPIRED'
                          ? 'Waktu pembayaran habis'
                          : 'Pesanan dibatalkan'),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 8),
            FadeSlideIn(
              delay: const Duration(milliseconds: 580),
              child: Text(
                ok
                    ? 'Terima kasih! Pesananmu ${widget.order.code} sedang kami siapkan.'
                    : 'Pesanan ${widget.order.code} tidak jadi diproses. Kamu bisa memesan lagi kapan saja.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF50706C),
                ),
              ),
            ),
            if (ok) ...[
              const SizedBox(height: 14),
              FadeSlideIn(
                delay: const Duration(milliseconds: 700),
                child: AnimatedNumber(
                  value: widget.order.total,
                  from: 0,
                  format: rupiah,
                  duration: const Duration(milliseconds: 1000),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 28),
            FadeSlideIn(
              delay: const Duration(milliseconds: 850),
              child: FilledButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/'),
                child: Text(ok ? 'Lihat pesanan' : 'Kembali'),
              ),
            ),
          ],
        ),
      ),
    );
    return Stack(
      children: [
        content,
        // Confetti hanya untuk pembayaran berhasil; berhenti sendiri (≤ 2,5 dtk) dan tidak menangkap sentuhan.
        if (ok)
          const Positioned.fill(
            child: ParticleBurst(origin: Alignment(0, -0.55), count: 80),
          ),
      ],
    );
  }
}

/// Centang yang "ditulis" dari awal ke akhir sesuai `t` (0..1).
class _CheckPainter extends CustomPainter {
  _CheckPainter(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w * .26, h * .53)
      ..lineTo(w * .44, h * .70)
      ..lineTo(w * .76, h * .34);
    final m = path.computeMetrics().first;
    canvas.drawPath(
      m.extractPath(0, m.length * t.clamp(0.0, 1.0)),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t;
}
