import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/config.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../state/providers.dart';
import '../widgets/async_view.dart';
import '../widgets/count_up.dart';
import '../widgets/pressable.dart';
import '../widgets/stagger.dart';
import '../widgets/illustration.dart';
import '../widgets/tier_style.dart';
import '../widgets/voucher_card.dart';

final _dateFmt = DateFormat('d MMM yyyy, HH:mm', 'id_ID');

String _maskPhone(String phone) => phone.length < 8 ? '+$phone' : '+${phone.substring(0, 5)}••••${phone.substring(phone.length - 3)}';

/// Tab Member: level, progres ke level berikutnya, keuntungan tiap level, voucher, dan riwayat poin.
class MemberTab extends ConsumerWidget {
  const MemberTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final points = user?.points ?? 0;
    final theme = Theme.of(context);
    final vouchers = ref.watch(activeVouchersProvider).value ?? const <VoucherView>[];
    final history = ref.watch(pointsHistoryProvider);
    final membership = ref.watch(membershipProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Member')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(pointsHistoryProvider);
          ref.invalidate(activeVouchersProvider);
          ref.invalidate(membershipProvider);
          await ref.read(authProvider.notifier).refreshProfile();
        },
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
          membership.when(
            data: (m) => FadeSlideIn(index: 0, playKey: 'member-card', child: _TierCard(user: user, points: points, m: m)),
            loading: () => const SizedBox(height: 220, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => _PlainPointsCard(user: user, points: points, onRetry: () => ref.invalidate(membershipProvider)),
          ),
          if (membership.value != null) ...[
            const SizedBox(height: 24),
            Text('Keuntungan tiap level', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            for (final (i, t) in membership.value!.tiers.indexed)
              FadeSlideIn(
                index: i + 1,
                playKey: 'member-tier-${t.id}',
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Pressable(child: _TierRow(tier: t, index: i, reached: i <= membership.value!.currentIndex, current: t.id == membership.value!.current.id)),
                ),
              ),
          ],
          if (vouchers.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Voucher untukmu', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            for (final (i, v) in vouchers.indexed)
              FadeSlideIn(index: i, playKey: 'member-voucher-${v.code}', child: Padding(padding: const EdgeInsets.only(bottom: 10), child: Pressable(child: VoucherCard(v, wide: true)))),
          ],
          const SizedBox(height: 24),
          Text('Riwayat poin', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          AsyncView<List<PointEntry>>(
            value: history,
            onRetry: () => ref.invalidate(pointsHistoryProvider),
            builder: (list) => list.isEmpty
                ? const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('Belum ada aktivitas poin. Poin masuk setelah pembayaran berhasil.', textAlign: TextAlign.center)))
                : Column(children: [
                    for (final e in list)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(e.label),
                        subtitle: Text(_dateFmt.format(e.at)),
                        trailing: Text('${e.delta > 0 ? '+' : ''}${e.delta}', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: e.delta > 0 ? brandColor : const Color(0xFFC2563B))),
                      ),
                  ]),
          ),
        ]),
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({required this.user, required this.points, required this.m});
  final UserProfile? user;
  final int points;
  final Membership m;

  @override
  Widget build(BuildContext context) {
    final style = tierStyle(m.currentIndex);
    final t = m.current;
    final white70 = Colors.white.withValues(alpha: .75);
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: style.gradient)),
        child: Stack(children: [
          Positioned(right: -30, top: -30, child: Container(width: 140, height: 140, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .08)))),
          Positioned(right: 50, bottom: -60, child: Container(width: 130, height: 130, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .06)))),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text((user?.name ?? '').isEmpty ? 'Member $appName' : user!.name!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                    Text(_maskPhone(user?.phone ?? ''), style: TextStyle(color: white70, fontSize: 13)),
                  ]),
                ),
                const SizedBox(width: 10),
                // Nama level bisa diubah admin (maks 20 karakter): lencana dibatasi lebarnya dan teksnya dipotong.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .2), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: .35))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.workspace_premium_rounded, size: 18, color: Colors.white),
                      const SizedBox(width: 6),
                      Flexible(child: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14))),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              Text('Saldo poin', style: TextStyle(color: white70, fontSize: 14)),
              CountUpText(value: points, style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w800, height: 1.1)),
              CountUpText(value: points * 100, format: (n) => 'Setara potongan ${rupiah(n)}', style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 13.5)),
              const SizedBox(height: 18),
              if (m.next != null) ...[
                Text('Belanja ${rupiah(m.remainingToNext ?? 0)} lagi untuk naik ke ${m.next!.name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedValue(
                    value: (m.progressPct / 100).clamp(0.0, 1.0),
                    builder: (_, v) => LinearProgressIndicator(value: v, minHeight: 9, backgroundColor: Colors.white.withValues(alpha: .25), valueColor: const AlwaysStoppedAnimation(Colors.white)),
                  ),
                ),
                const SizedBox(height: 6),
                Text('Total belanja ${rupiah(m.lifetimeSpend)} • target ${rupiah(m.next!.minSpend)}', style: TextStyle(color: white70, fontSize: 12)),
              ] else
                Text('Kamu sudah di level tertinggi. Total belanja ${rupiah(m.lifetimeSpend)}.', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5)),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _Perk(icon: Icons.stars, text: 'Poin ${t.multiplierLabel}'),
                _Perk(icon: Icons.local_offer, text: t.hasDiscount ? 'Diskon ${t.discountPct}%${t.maxDiscount != null ? ' (maks ${rupiah(t.maxDiscount!)})' : ''}' : 'Naik level untuk dapat diskon'),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Perk extends StatelessWidget {
  const _Perk({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: .22), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5))),
        ]),
      );
}

/// Dipakai bila data level gagal dimuat: saldo poin tetap tampil.
class _PlainPointsCard extends StatelessWidget {
  const _PlainPointsCard({required this.user, required this.points, required this.onRetry});
  final UserProfile? user;
  final int points;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), gradient: const LinearGradient(colors: [Color(0xFF14A398), Color(0xFF063B38)])),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Saldo poin', style: TextStyle(color: Colors.white.withValues(alpha: .75))),
          Text('$points', style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, style: TextButton.styleFrom(foregroundColor: Colors.white), child: const Text('Muat ulang data level')),
        ]),
      );
}

class _TierRow extends StatelessWidget {
  const _TierRow({required this.tier, required this.index, required this.reached, required this.current});
  final Tier tier;
  final int index;
  final bool reached, current;

  @override
  Widget build(BuildContext context) {
    final style = tierStyle(index);
    final theme = Theme.of(context);
    return Opacity(
      opacity: reached ? 1 : .62,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: current ? style.accent : const Color(0xFFD5EBE8), width: current ? 2 : 1)),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: style.gradient)),
            child: Icon(reached ? Icons.workspace_premium_rounded : Icons.lock_outline_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(tier.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                if (current) ...[
                  const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: style.accent, borderRadius: BorderRadius.circular(10)), child: const Text('Levelmu', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))),
                ],
              ]),
              const SizedBox(height: 2),
              Text(tier.minSpend == 0 ? 'Level awal untuk semua member' : 'Total belanja ≥ ${rupiah(tier.minSpend)}', style: theme.textTheme.bodySmall),
              const SizedBox(height: 6),
              Text('Poin ${tier.multiplierLabel}  •  ${tier.hasDiscount ? 'Diskon ${tier.discountPct}%${tier.maxDiscount != null ? ' (maks ${rupiah(tier.maxDiscount!)})' : ''}' : 'Tanpa diskon'}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Tab Merch: katalog merchandise belum ada, jadi halaman "segera hadir".
class MerchTab extends StatelessWidget {
  const MerchTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Merch')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Illustration('merch', width: 240, height: 240),
            const SizedBox(height: 12),
            Text('Merchandise segera hadir', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Tumbler, tote bag, dan lainnya sedang kami siapkan. Pantau terus beranda untuk kabar terbarunya.', textAlign: TextAlign.center, style: theme.textTheme.bodyLarge?.copyWith(color: const Color(0xFF50706C))),
          ]),
        ),
      ),
    );
  }
}
