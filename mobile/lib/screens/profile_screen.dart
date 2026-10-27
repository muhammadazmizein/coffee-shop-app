import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../core/api.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../state/providers.dart';
import '../widgets/animated_number.dart';
import '../widgets/animated_ring.dart';
import '../widgets/particle_burst.dart';
import '../widgets/product_card.dart' show textScale;
import '../widgets/pulse.dart';
import '../widgets/tier_style.dart';
import '../widgets/voucher_card.dart';

const _border = Color(0xFFD5EBE8);

/// Jumlah notifikasi belum dibaca: dari Kotak Masuk bila sudah dimuat, kalau belum dari /me.
final unreadCountProvider = Provider<int>(
  (ref) =>
      ref.watch(inboxProvider).value?.unread ??
      ref.watch(authProvider).value?.unread ??
      0,
);

/// Tab Saya: kartu profil, Daily Check-In, menu akun, dan pengingat melengkapi profil.
class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final unread = ref.watch(unreadCountProvider);
    final showCompletion = user != null && !user.isComplete;

    return Scaffold(
      body: Stack(
        children: [
          RefreshIndicator(
            edgeOffset: MediaQuery.paddingOf(context).top,
            onRefresh: () async {
              ref.invalidate(checkInProvider);
              ref.invalidate(inboxProvider);
              ref.invalidate(membershipProvider);
              ref.invalidate(addressesProvider);
              await ref.read(authProvider.notifier).refreshProfile();
            },
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _ProfileHeader(user: user),
                const _CheckInCard(),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Text(
                    'Akun',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  // Material (bukan Container berwarna) agar efek sentuh ListTile terlihat.
                  child: Material(
                    color: Colors.white,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: _border),
                    ),
                    child: Column(
                      children: [
                        _MenuTile(
                          icon: Icons.inbox_rounded,
                          title: 'Kotak Masuk',
                          badge: unread,
                          onTap: () => context.push('/inbox'),
                        ),
                        _MenuTile(
                          icon: Icons.receipt_long_rounded,
                          title: 'Pesanan Saya',
                          onTap: () => context.push('/orders'),
                        ),
                        _MenuTile(
                          icon: Icons.location_on_rounded,
                          title: 'Alamat Pengiriman',
                          onTap: () => context.push('/addresses'),
                        ),
                        _MenuTile(
                          icon: Icons.local_offer_rounded,
                          title: 'Voucher Saya',
                          onTap: () => showVouchersSheet(context),
                        ),
                        _MenuTile(
                          icon: Icons.stars_rounded,
                          title: 'Riwayat Poin',
                          onTap: () =>
                              ref.read(shellTabProvider.notifier).go(2),
                        ),
                        _MenuTile(
                          icon: Icons.logout_rounded,
                          title: 'Keluar',
                          color: const Color(0xFFC2563B),
                          last: true,
                          onTap: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Keluar dari akun?'),
                                content: const Text(
                                  'Kamu perlu masuk lagi dengan kode OTP.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Batal'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Keluar'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) {
                              ref.read(cartProvider.notifier).clear();
                              ref.read(authProvider.notifier).signOut();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: showCompletion ? 120 : 28),
              ],
            ),
          ),
          if (showCompletion)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _CompletionBar(user: user),
            ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({required this.user});
  final UserProfile? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(membershipProvider).value;
    final style = tierStyle(m?.currentIndex ?? 0);
    final name = (user?.name ?? '').trim();
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final top = MediaQuery.paddingOf(context).top;

    return Padding(
      padding: const EdgeInsets.only(bottom: 34 + 18),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(20, top + 12, 12, 56),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF14A398), Color(0xFF063B38)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: Row(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .85),
                      width: 2.5,
                    ),
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: style.gradient),
                    ),
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hai,',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .75),
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        name.isEmpty ? 'Lengkapi namamu' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '+${user?.phone ?? ''}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .75),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.push('/profile/edit'),
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: -34,
            child: Material(
              color: Colors.white,
              elevation: 4,
              shadowColor: Colors.black.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => ref.read(shellTabProvider.notifier).go(2),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.workspace_premium_rounded,
                                color: style.accent,
                                size: 30,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Level',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                    Text(
                                      m?.current.name ?? '-',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (m != null)
                                      Text(
                                        m.next != null
                                            ? '${m.progressPct.round()}% ke ${m.next!.name}'
                                            : 'Level tertinggi',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const VerticalDivider(width: 24, color: _border),
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.stars_rounded,
                                color: Color(0xFFD99A1E),
                                size: 30,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Poin',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                    AnimatedNumber(
                                      value: user?.points ?? 0,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ],
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
          ),
        ],
      ),
    );
  }
}

// ---------- Daily Check-In ----------

class _CheckInCard extends ConsumerStatefulWidget {
  const _CheckInCard();

  @override
  ConsumerState<_CheckInCard> createState() => _CheckInCardState();
}

class _CheckInCardState extends ConsumerState<_CheckInCard> {
  bool _busy = false;
  // Kunci per tile hari, untuk mengetahui posisi tile yang diklaim (asal ledakan koin).
  final Map<int, GlobalKey> _tileKeys = {};

  /// Pusat tile hari `day` dalam koordinat layar, atau null bila belum terlihat.
  Offset? _tileCenter(int day) {
    final box = _tileKeys[day]?.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return null;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  /// Percikan koin dari tile (satu kali) lewat Overlay supaya tidak terpotong daftar horizontal.
  void _coinBurst(Offset center) {
    if (MediaQuery.disableAnimationsOf(context)) return;
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    final size = MediaQuery.sizeOf(context);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: ParticleBurst(
          origin: Alignment(center.dx / size.width * 2 - 1, center.dy / size.height * 2 - 1),
          count: 34,
          colors: const [Color(0xFFFFE08A), Color(0xFFF3C657), Color(0xFFE3A92E), Color(0xFFFFFFFF)],
          shape: ParticleShape.circle,
          duration: const Duration(milliseconds: 1300),
          minSpeed: 140,
          maxSpeed: 420,
          gravity: 760,
          size: 11,
          spread: math.pi * 1.6,
          seed: 11,
          onDone: () => entry.remove(),
        ),
      ),
    );
    overlay.insert(entry);
  }

  Future<void> _claim() async {
    final dayToClaim = ref.read(checkInProvider).value?.dayInCycle;
    final origin = dayToClaim == null ? null : _tileCenter(dayToClaim);
    setState(() => _busy = true);
    try {
      final r = await ref
          .read(apiProvider)
          .post(
            '/me/checkin',
            null,
            (d) => CheckInView.fromJson(Map<String, dynamic>.from(d as Map)),
            auth: true,
          );
      HapticFeedback.mediumImpact();
      if (origin != null) _coinBurst(origin);
      ref.invalidate(checkInProvider);
      ref.invalidate(inboxProvider);
      ref.invalidate(pointsHistoryProvider);
      ref.read(authProvider.notifier).refreshProfile();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _CoinDialog(points: r.awarded ?? 0, day: r.dayInCycle),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
        ref.invalidate(checkInProvider);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(checkInProvider);
    final theme = Theme.of(context);
    final c = async.value;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Check-In',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Row(
                        children: [
                          if (c != null && c.streak > 0) ...[
                            const _Flame(),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              c == null
                                  ? 'Check-in tiap hari, kumpulkan poin'
                                  : (c.streak > 0
                                        ? 'Streak ${c.streak} hari berturut-turut'
                                        : 'Mulai streak-mu hari ini'),
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => AlertDialog(
                      icon: const Icon(
                        Icons.event_available_rounded,
                        color: brandColor,
                        size: 34,
                      ),
                      title: const Text('Cara kerja Check-In'),
                      content: const Text(
                        'Buka app dan check-in setiap hari untuk mendapat poin. Hadiah naik tiap hari berturut-turut, dan hari ke-7 paling besar.\n\nKalau satu hari terlewat, streak kembali ke hari 1. Poin bisa ditukar jadi potongan harga di checkout.',
                      ),
                      actions: [
                        FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Mengerti'),
                        ),
                      ],
                    ),
                  ),
                  child: const Text('Detail'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (c == null)
            SizedBox(
              height: 96,
              child: Center(
                child: async.hasError
                    ? TextButton(
                        onPressed: () => ref.invalidate(checkInProvider),
                        child: const Text('Muat ulang check-in'),
                      )
                    : const CircularProgressIndicator(),
              ),
            )
          else ...[
            SizedBox(
            height: 104 * textScale(context),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
                itemCount: c.rewards.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => KeyedSubtree(
                  key: _tileKeys.putIfAbsent(c.rewards[i].day, GlobalKey.new),
                  child: _DayTile(
                    day: c.rewards[i],
                    isNext: !c.claimedToday && c.rewards[i].day == c.dayInCycle,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12, right: 16),
              child: c.claimedToday
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5F6F3),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: brandColor,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Sudah check-in hari ini. Sampai jumpa besok!',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: brandColor,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: _busy ? null : _claim,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.bolt_rounded),
                      label: Text('Check-in sekarang  +${c.nextPoints} poin'),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.day, required this.isNext});
  final CheckInDay day;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final special = day.day == 7;
    final color = day.claimed
        ? brandColor
        : (isNext ? const Color(0xFFD99A1E) : const Color(0xFF9DB1AE));
    final icon = day.claimed
        ? Icons.check_circle_rounded
        : (special ? Icons.card_giftcard_rounded : Icons.stars_rounded);
    // Tile hari berjalan berdenyut emas lembut; berhenti otomatis setelah diklaim.
    return Pulse(
      active: isNext,
      maxScale: 1.045,
      period: const Duration(milliseconds: 1300),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOut,
        width: 68,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: day.claimed
              ? const Color(0xFFE5F6F3)
              : (isNext ? const Color(0xFFFFF6DE) : const Color(0xFFF3F7F6)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isNext
                ? const Color(0xFFD99A1E)
                : (day.claimed ? brandColor.withValues(alpha: .4) : _border),
            width: isNext ? 2 : 1,
          ),
          boxShadow: [
            if (isNext)
              BoxShadow(color: const Color(0xFFD99A1E).withValues(alpha: .28), blurRadius: 12, spreadRadius: 0.5),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Saat berpindah ke "diklaim", ikon membal masuk sambil berputar sedikit (centang).
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 520),
              switchInCurve: Curves.elasticOut,
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                child: RotationTransition(turns: Tween<double>(begin: .18, end: 0).animate(anim), child: child),
              ),
              child: Icon(icon, key: ValueKey(icon), color: color, size: 28),
            ),
            Text(
              '+${day.points}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: day.claimed || isNext
                    ? const Color(0xFF0B2E2B)
                    : const Color(0xFF6B8985),
              ),
            ),
            Text(
              'Hari ${day.day}',
              maxLines: 1,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ikon api streak: bergoyang halus satu kali saat muncul.
class _Flame extends StatelessWidget {
  const _Flame();

  @override
  Widget build(BuildContext context) {
    const icon = Icon(Icons.local_fire_department_rounded, size: 18, color: Color(0xFFE5701E));
    if (MediaQuery.disableAnimationsOf(context)) return icon;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1000),
      builder: (_, t, child) => Transform.rotate(angle: math.sin(t * math.pi * 5) * .32 * (1 - t), child: child),
      child: icon,
    );
  }
}

class _CoinDialog extends StatelessWidget {
  const _CoinDialog({required this.points, required this.day});
  final int points, day;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 220,
            height: 130,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Percikan koin kecil di belakang koin utama.
                const Positioned.fill(
                  child: ParticleBurst(
                    origin: Alignment(0, 0),
                    count: 26,
                    colors: [Color(0xFFFFE08A), Color(0xFFF3C657), Color(0xFFFFFFFF)],
                    shape: ParticleShape.circle,
                    duration: Duration(milliseconds: 1100),
                    minSpeed: 90,
                    maxSpeed: 260,
                    gravity: 420,
                    size: 9,
                    spread: math.pi * 2,
                    seed: 5,
                  ),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: reduce ? 1 : 0, end: 1),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutBack,
                  builder: (_, v, child) => Transform(
                    alignment: Alignment.center,
                    // koin "berputar" satu kali di sumbu tegak sambil membesar
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, .0012)
                      ..rotateY((1 - v) * math.pi * 2)
                      ..scaleByDouble(v.clamp(0.0, 1.2), v.clamp(0.0, 1.2), 1, 1),
                    child: child,
                  ),
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [Color(0xFFFFE08A), Color(0xFFE3A92E)]),
                    ),
                    child: const Icon(Icons.stars_rounded, color: Colors.white, size: 56),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          AnimatedNumber(
            value: points,
            from: 0,
            format: (v) => '+$v poin',
            duration: const Duration(milliseconds: 800),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text('Check-in hari ke-$day berhasil', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Mantap')),
      ],
    );
  }
}

// ---------- Menu akun ----------

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.badge = 0,
    this.color,
    this.last = false,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final int badge;
  final Color? color;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = color ?? brandColor;
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: c, size: 22),
          ),
          title: Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD33F3F),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge > 99 ? '99+' : '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
        if (!last)
          const Divider(height: 1, indent: 70, endIndent: 16, color: _border),
      ],
    );
  }
}

// ---------- Kelengkapan profil ----------

class _CompletionBar extends StatelessWidget {
  const _CompletionBar({required this.user});
  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final pct = user.completionPercent;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .1),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: AnimatedProgressRing(
                    value: pct / 100,
                    backgroundColor: const Color(0xFFE3EEEC),
                    color: brandColor,
                  ),
                ),
                AnimatedNumber(
                  value: pct,
                  from: 0,
                  format: (v) => '$v%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Isi Profil Kamu Yuk!',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
                ),
                Text(
                  'Biar kami bisa kenal kamu lebih dekat',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => context.push('/profile/edit'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
            child: const Text('Lengkapi'),
          ),
        ],
      ),
    );
  }
}

class AddressFormScreen extends ConsumerStatefulWidget {
  const AddressFormScreen({super.key});

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  final _form = GlobalKey<FormState>();
  final _label = TextEditingController(text: 'Rumah');
  final _recipient = TextEditingController();
  final _phone = TextEditingController();
  final _detail = TextEditingController();
  double? _lat, _lng;
  bool _locating = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).value;
    _recipient.text = user?.name ?? '';
    _phone.text = user == null ? '' : '0${user.phone.replaceFirst('62', '')}';
  }

  @override
  void dispose() {
    for (final c in [_label, _recipient, _phone, _detail]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'Aktifkan layanan lokasi di perangkat';
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw 'Izin lokasi ditolak. Aktifkan di pengaturan aplikasi.';
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_lat == null) {
      setState(() => _error = 'Tentukan lokasi pengantaran dulu');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(apiProvider)
          .post(
            '/addresses',
            {
              'label': _label.text.trim(),
              'recipient': _recipient.text.trim(),
              'phone': _phone.text.trim(),
              'detail': _detail.text.trim(),
              'lat': _lat,
              'lng': _lng,
            },
            (_) {},
            auth: true,
          );
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alamat baru')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _label,
              decoration: const InputDecoration(
                labelText: 'Label (Rumah, Kantor)',
              ),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _recipient,
              decoration: const InputDecoration(labelText: 'Nama penerima'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Nomor HP penerima'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _detail,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Alamat lengkap',
                hintText: 'Jalan, nomor, patokan',
              ),
              validator: (v) => (v == null || v.trim().length < 5)
                  ? 'Minimal 5 karakter'
                  : null,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _locating ? null : _locate,
              icon: _locating
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: Text(
                _lat == null
                    ? 'Gunakan lokasi saya saat ini'
                    : 'Lokasi tersimpan (${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)})',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
