import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/format.dart';
import '../models/models.dart';
import '../state/providers.dart';
import '../state/favorites.dart';
import '../state/home_ui.dart';
import '../widgets/category_row.dart';
import '../widgets/count_up.dart';
import '../widgets/fly_to_cart.dart';
import '../widgets/home_footer.dart';
import '../widgets/motion.dart';
import '../widgets/pressable.dart';
import '../widgets/stagger.dart';
import '../widgets/tab_fade.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton.dart';
import '../widgets/illustration.dart';
import '../widgets/outlet_picker.dart';
import '../widgets/product_card.dart';
import '../widgets/voucher_card.dart';
import '../widgets/bottom_bar.dart';
import '../widgets/tier_style.dart';
import 'member_screen.dart';
import 'profile_screen.dart';

const _espresso = Color(0xFF0B2E2B);

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    // Kotak Masuk diperbarui berkala agar lencana belum-dibaca tidak basi.
    _refresh = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) ref.invalidate(inboxProvider);
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(shellTabProvider);
    final count = ref.watch(cartCountProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final outlets = ref.watch(outletsProvider);

    // Pilih outlet pertama otomatis agar menu langsung tampil.
    if (ref.watch(selectedOutletProvider) == null && outlets.value?.isNotEmpty == true) {
      Future.microtask(() {
        if (ref.read(selectedOutletProvider) == null) ref.read(selectedOutletProvider.notifier).select(outlets.value!.first);
      });
    }

    return Scaffold(
      body: TabFade(index: tab, children: const [HomeTab(), MenuTab(), MemberTab(), MerchTab(), ProfileTab()]),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedSize(
          duration: motionDuration(context, const Duration(milliseconds: 240)),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: count > 0
              ? Material(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: PulseOnChange(
                      scale: 1.04,
                      child: FilledButton.icon(
                        key: CartTarget.barKey,
                        onPressed: () => context.push('/cart'),
                        icon: PulseOnChange(scale: 1.4, child: Badge.count(count: count, child: const Icon(Icons.shopping_bag_outlined))),
                        label: Text('Lihat keranjang • ${rupiah(subtotal)}'),
                      ),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        AppBottomBar(index: tab, badgeIndex: ref.watch(unreadCountProvider) > 0 ? 4 : null, onTap: (i) => ref.read(shellTabProvider.notifier).go(i)),
      ]),
    );
  }
}

// ======================= BERANDA =======================

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    final outlet = ref.read(selectedOutletProvider);
    ref.invalidate(ordersProvider);
    ref.invalidate(activeVouchersProvider);
    ref.read(authProvider.notifier).refreshProfile();
    if (outlet != null) {
      ref.invalidate(popularProvider(outlet.id));
      ref.invalidate(menuProvider(outlet.id));
      await ref.read(menuProvider(outlet.id).future);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outlet = ref.watch(selectedOutletProvider);
    final menu = outlet == null ? null : ref.watch(menuProvider(outlet.id));
    final popular = outlet == null ? const <String>{} : (ref.watch(popularProvider(outlet.id)).value ?? const <String>[]).toSet();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: CustomScrollView(slivers: [
          const SliverToBoxAdapter(child: FadeSlideIn(index: 0, playKey: 'home-header', child: _Header())),
          const SliverToBoxAdapter(child: FadeSlideIn(index: 1, playKey: 'home-search', child: _SearchBar())),
          SliverToBoxAdapter(child: FadeSlideIn(index: 2, playKey: 'home-banners', child: _Banners(outlet: outlet))),
          if (menu?.value != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: FadeSlideIn(
                  index: 3,
                  playKey: 'home-cats',
                  child: CategoryRow(
                  categories: menu!.value!,
                  onTap: (c) {
                    ref.read(menuCategoryProvider.notifier).select(c.id);
                    ref.read(shellTabProvider.notifier).go(1);
                  },
                ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: FadeSlideIn(index: 4, playKey: 'home-quick', child: _QuickActions())),
          const SliverToBoxAdapter(child: FadeSlideIn(index: 5, playKey: 'home-reorder', child: _ReorderSection())),
          const SliverToBoxAdapter(child: FadeSlideIn(index: 6, playKey: 'home-voucher', child: _VoucherSection())),
          if (outlet != null) SliverToBoxAdapter(child: FadeSlideIn(index: 7, playKey: 'home-popular', child: _PopularSection(outletId: outlet.id))),
          if (menu == null || menu.isLoading && !menu.hasValue)
            const SliverToBoxAdapter(child: MenuSkeleton())
          else if (menu.hasError && !menu.hasValue)
            SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Menu belum bisa dimuat',
                message: menu.error.toString(),
                actionLabel: 'Coba lagi',
                onAction: () => ref.invalidate(menuProvider(outlet!.id)),
              ),
            )
          else
            ...productSections(context, menu.value!, limit: 4, popularIds: popular, keyPrefix: 'home-grid', onSeeAll: (c) {
              ref.read(menuCategoryProvider.notifier).select(c.id);
              ref.read(shellTabProvider.notifier).go(1);
            }),
          SliverToBoxAdapter(child: HomeFooter(outlet: outlet)),
        ]),
      ),
    );
  }
}

/// Kerangka grid menu saat data belum tiba: judul kategori + 4 kartu (lebar sama dengan grid asli).
class MenuSkeleton extends StatelessWidget {
  const MenuSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final w = (MediaQuery.sizeOf(context).width - 32 - 12) / 2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Skeleton(width: 120, height: 22),
        const SizedBox(height: 14),
        Wrap(spacing: 12, runSpacing: 12, children: [for (var i = 0; i < 4; i++) SizedBox(width: w, child: const ProductCardSkeleton())]),
      ]),
    );
  }
}

/// Kolom cari semu di beranda: mengetuknya membuka tab Menu dan memfokuskan kolom cari di sana.
class _SearchBar extends ConsumerWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            ref.read(menuSearchFocusProvider.notifier).request();
            ref.read(shellTabProvider.notifier).go(1);
          },
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFD5EBE8))),
            child: Row(children: [
              const Icon(Icons.search_rounded, color: Color(0xFF50706C)),
              const SizedBox(width: 10),
              Expanded(child: Text('Cari kopi, roti, atau minuman…', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF7C9692)))),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final outlet = ref.watch(selectedOutletProvider);
    final membership = ref.watch(membershipProvider).value;
    final unread = ref.watch(unreadCountProvider);
    final theme = Theme.of(context);
    final first = (user?.name ?? '').trim().split(' ').first;
    final open = outlet != null && outletOpenNow(outlet);
    final delivery = (outlet?.deliveryRadiusKm ?? 0) > 0;

    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 14, 20, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFCFF3EE), Color(0xFFF4FAF9)]),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(first.isEmpty ? 'Halo!' : 'Halo, $first!', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: _espresso, fontSize: 20)),
              Text('Mau minum apa hari ini?', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF50706C))),
            ]),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .38),
            child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => ref.read(shellTabProvider.notifier).go(2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 8)]),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.workspace_premium_rounded, size: 18, color: membership == null ? const Color(0xFFD99A1E) : tierStyle(membership.currentIndex).accent),
                const SizedBox(width: 6),
                Flexible(
                  child: CountUpText(
                    value: user?.points ?? 0,
                    format: (n) => '${membership != null ? '${membership.current.name} • ' : ''}$n poin',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ]),
            ),
          ),
          ),
          IconButton(
            onPressed: () => context.push('/inbox'),
            icon: Badge(isLabelVisible: unread > 0, label: Text(unread > 99 ? '99+' : '$unread'), child: const Icon(Icons.notifications_none_rounded, size: 27)),
          ),
        ]),
        const SizedBox(height: 16),
        Material(
          color: Colors.white,
          elevation: 3,
          shadowColor: Colors.black.withValues(alpha: .15),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => pickOutlet(context, ref),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.storefront, color: _espresso),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(outlet?.name ?? 'Pilih outlet', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      if (outlet != null) Text(outlet.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                    ]),
                  ),
                  const Icon(Icons.keyboard_arrow_down),
                ]),
                if (outlet != null) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    _Pill(icon: open ? Icons.check_circle : Icons.schedule, text: open ? 'Buka • tutup ${hourLabel(outlet.closeHour)}' : 'Tutup • buka ${hourLabel(outlet.openHour)}', ok: open),
                    _Pill(icon: delivery ? Icons.delivery_dining : Icons.block, text: delivery ? 'Delivery ≤ ${_km(outlet.deliveryRadiusKm)} km' : 'Tanpa delivery', ok: delivery),
                    const _Pill(icon: Icons.shopping_bag_outlined, text: 'Pickup', ok: true),
                  ]),
                ],
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

String _km(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString().replaceAll('.', ',');

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, required this.ok});
  final IconData icon;
  final String text;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? const Color(0xFF2F7A3E) : const Color(0xFF6B8985);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

// ---------- Banner ----------

class _BannerData {
  const _BannerData({required this.title, required this.body, required this.cta, required this.art, required this.colors, required this.onTap, this.imageUrl});
  final String title, body, cta, art;
  final String? imageUrl; // foto banner dari admin (bila ada)
  final List<Color> colors;
  final void Function(BuildContext, WidgetRef) onTap;
}

/// Ilustrasi yang boleh dipakai promo dari server; selain ini dipakai gambar bawaan (aman untuk app versi lama).
const _knownArt = {'onboarding_1', 'onboarding_2', 'onboarding_3', 'product_latte', 'product_matcha', 'product_chocolate', 'product_croissant', 'product_donut', 'product_boba'};

const _tints = [
  [Color(0xFFCDEFE9), Color(0xFF86D8CC)],
  [Color(0xFFD6EEF5), Color(0xFF93D3E3)],
  [Color(0xFFFCE3B8), Color(0xFFF3C27C)],
];

/// Banner dari slide promo admin. Tombol voucher memasang kodenya untuk checkout.
_BannerData _bannerFromPromo(PromoSlide s, int i) => _BannerData(
      title: s.title,
      body: s.body,
      cta: s.ctaLabel ?? (s.voucherCode != null ? 'Pakai voucher' : 'Lihat menu'),
      art: _knownArt.contains(s.art) ? s.art! : 'onboarding_1',
      imageUrl: ProductImage.resolve(s.imageUrl),
      colors: _tints[i % _tints.length],
      onTap: (context, ref) {
        if (s.voucherCode != null) {
          ref.read(pendingVoucherProvider.notifier).set(s.voucherCode);
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text('Kode ${s.voucherCode} akan dipakai di checkout')));
        }
        ref.read(shellTabProvider.notifier).go(1);
      },
    );

class _Banners extends ConsumerStatefulWidget {
  const _Banners({required this.outlet});
  final Outlet? outlet;

  @override
  ConsumerState<_Banners> createState() => _BannersState();
}

class _BannersState extends ConsumerState<_Banners> {
  final _controller = PageController(viewportFraction: 0.92);
  Timer? _timer;
  int _index = 0;
  int _count = 3;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_controller.hasClients || _count < 2) return;
      _controller.animateToPage((_index + 1) % _count, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  List<_BannerData> _static() {
    final radius = widget.outlet?.deliveryRadiusKm ?? 0;
    return [
      _BannerData(title: 'Kopi enak, dekat denganmu', body: 'Pesan lewat app, tinggal ambil atau tunggu diantar.', cta: 'Pesan sekarang', art: 'product_latte', colors: _tints[0], onTap: (c, r) => r.read(shellTabProvider.notifier).go(1)),
      _BannerData(title: 'Diantar kurir kami', body: radius > 0 ? 'Langsung ke depan pintu, jarak sampai ${_km(radius)} km dari outlet.' : 'Ambil di outlet tanpa antre.', cta: 'Lihat menu', art: 'onboarding_2', colors: _tints[1], onTap: (c, r) => r.read(shellTabProvider.notifier).go(1)),
      _BannerData(title: 'Setiap pesanan ada poinnya', body: '1 poin tiap belanja Rp10.000, bisa ditukar jadi potongan harga.', cta: 'Lihat poin', art: 'onboarding_3', colors: _tints[2], onTap: (c, r) => r.read(shellTabProvider.notifier).go(2)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final promos = ref.watch(welcomePromosProvider);
    final h = 188 * textScale(context);
    // Selama promo dimuat tampilkan kerangka; bila kosong/gagal pakai 3 banner statis.
    if (promos.isLoading && !promos.hasValue) {
      return SizedBox(height: h + 18, child: const Padding(padding: EdgeInsets.fromLTRB(16, 6, 16, 24), child: Skeleton(height: double.infinity, radius: 22)));
    }
    final slides = promos.value ?? const <PromoSlide>[];
    final banners = slides.isEmpty ? _static() : [for (final (i, s) in slides.indexed) _bannerFromPromo(s, i)];
    _count = banners.length;
    if (_index >= banners.length) _index = 0;

    return Column(children: [
      SizedBox(
        height: h,
        child: PageView.builder(
          controller: _controller,
          itemCount: banners.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6), child: _BannerCard(banners[i])),
        ),
      ),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < banners.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
            width: i == _index ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(color: i == _index ? _espresso : _espresso.withValues(alpha: .2), borderRadius: BorderRadius.circular(3)),
          ),
      ]),
    ]);
  }
}

class _BannerCard extends ConsumerWidget {
  const _BannerCard(this.b);
  final _BannerData b;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPhoto = b.imageUrl != null;
    final onPhoto = hasPhoto ? Colors.white : _espresso;
    final art = Illustration(b.art, width: 150);
    return Pressable(
      onTap: () => b.onTap(context, ref),
      child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), gradient: LinearGradient(colors: b.colors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Stack(children: [
        if (hasPhoto) ...[
          Positioned.fill(child: Image.network(b.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink())),
          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Colors.black.withValues(alpha: .62), Colors.black.withValues(alpha: .05)])))),
        ] else
          Positioned(right: -14, bottom: -6, top: 10, child: art),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 0, 16),
          child: SizedBox(
            width: MediaQuery.sizeOf(context).width * 0.5,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: onPhoto, height: 1.15)),
                const SizedBox(height: 4),
                Text(b.body, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: hasPhoto ? Colors.white.withValues(alpha: .92) : const Color(0xFF1F4F4B), height: 1.25)),
              ]),
              FilledButton(
                onPressed: () => b.onTap(context, ref),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 36), tapTargetSize: MaterialTapTargetSize.shrinkWrap, padding: const EdgeInsets.symmetric(horizontal: 16), backgroundColor: hasPhoto ? Colors.white : _espresso, foregroundColor: hasPhoto ? _espresso : Colors.white),
                child: Text(b.cta, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
              ),
            ]),
          ),
        ),
      ]),
      ),
    );
  }
}

// ---------- Aksi cepat ----------

class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget tile(IconData icon, String label, Color color, VoidCallback onTap) => Expanded(
          child: Pressable(
            child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(children: [
                Container(width: 54, height: 54, decoration: BoxDecoration(color: color.withValues(alpha: .15), shape: BoxShape.circle), child: Icon(icon, color: color, size: 26)),
                const SizedBox(height: 6),
                Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              ]),
            ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      child: Row(children: [
        tile(Icons.local_cafe, 'Pesan', const Color(0xFF0F766E), () => ref.read(shellTabProvider.notifier).go(1)),
        tile(Icons.receipt_long, 'Pesanan', const Color(0xFF2F7A3E), () => context.push('/orders')),
        tile(Icons.local_offer, 'Voucher', const Color(0xFFC2563B), () => showVouchersSheet(context)),
        tile(Icons.workspace_premium_rounded, 'Member', const Color(0xFFD99A1E), () => ref.read(shellTabProvider.notifier).go(2)),
      ]),
    );
  }

}

// ---------- Voucher ----------

class _VoucherSection extends ConsumerWidget {
  const _VoucherSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(activeVouchersProvider).value ?? const <VoucherView>[];
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 24, 20, 10), child: Text('Voucher untukmu', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
      SizedBox(
        height: 124 * textScale(context),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, i) => Pressable(child: VoucherCard(list[i])),
        ),
      ),
    ]);
  }
}

// ---------- Order Lagi ----------

class _ReorderSection extends ConsumerStatefulWidget {
  const _ReorderSection();

  @override
  ConsumerState<_ReorderSection> createState() => _ReorderSectionState();
}

class _ReorderSectionState extends ConsumerState<_ReorderSection> {
  String? _busy;

  Future<void> _again(OrderView o) async {
    setState(() => _busy = o.id);
    try {
      final r = await reorder(ref, o);
      if (!mounted) return;
      final msg = r.added == 0
          ? 'Menu pesanan ini sedang tidak tersedia di outlet yang dipilih.'
          : '${r.added} item masuk keranjang${r.skipped > 0 ? ' (${r.skipped} item tidak tersedia dilewati)' : ''}';
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(msg)));
      if (r.added > 0) context.push('/cart');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    const done = {'COMPLETED', 'PAID', 'PREPARING', 'READY', 'ON_DELIVERY'};
    final ordersAsync = ref.watch(ordersProvider);
    final orders = (ordersAsync.value ?? const <OrderView>[]).where((o) => done.contains(o.status) && o.items.isNotEmpty).take(5).toList();
    final theme = Theme.of(context);
    if (ordersAsync.isLoading && !ordersAsync.hasValue) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Skeleton(width: 110, height: 22), const SizedBox(height: 12), Skeleton(height: 120 * textScale(context), radius: 18)]),
      );
    }
    if (orders.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 24, 20, 10), child: Text('Order lagi', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
      SizedBox(
        height: 172 * textScale(context),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: orders.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, i) {
            final o = orders[i];
            final first = o.items.first;
            final art = productIllustration(Product(id: '', name: first.name, price: 0, groups: const []));
            return Pressable(
              child: Container(
              width: 290,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFD5EBE8))),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(o.outletName ?? 'Outlet', style: theme.textTheme.labelMedium?.copyWith(color: const Color(0xFF0F766E), fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(text: '${first.qty}x ${first.name}'),
                          if (o.items.length > 1) TextSpan(text: '  +${o.items.length - 1} lainnya', style: TextStyle(fontWeight: FontWeight.w500, color: theme.colorScheme.primary)),
                        ]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.25),
                      ),
                    ]),
                    OutlinedButton(
                      onPressed: _busy == null ? () => _again(o) : null,
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 22), side: const BorderSide(color: Color(0xFF0F766E), width: 1.5)),
                      child: _busy == o.id ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text('Beli • ${rupiah(o.total)}'),
                    ),
                  ]),
                ),
                Illustration(art, width: 84, height: 84),
              ]),
            ),
            );
          },
        ),
      ),
    ]);
  }
}

// ---------- Terlaris ----------

class _PopularSection extends ConsumerWidget {
  const _PopularSection({required this.outletId});
  final String outletId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popular = ref.watch(popularProvider(outletId));
    final menu = ref.watch(menuProvider(outletId));
    final loading = (popular.isLoading && !popular.hasValue) || (menu.isLoading && !menu.hasValue);
    final title = Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Row(children: [
        Text('Terlaris', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(width: 6),
        const Text('🔥'),
      ]),
    );
    // Kartu 140 lebar: gambar 132 + jarak/padding 28 + nama 2 baris dan harga (≈56 pada skala 1).
    final height = 166 + 60 * textScale(context);
    if (loading) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        title,
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 3,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, _) => const SizedBox(width: 140, child: ProductCardSkeleton()),
          ),
        ),
      ]);
    }
    final ids = popular.value ?? const <String>[];
    final cats = menu.value;
    if (ids.isEmpty || cats == null) return const SizedBox.shrink();
    final byId = {for (final c in cats) for (final p in c.products) p.id: p};
    final products = [for (final id in ids) if (byId[id] != null) byId[id]!];
    if (products.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      title,
      SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: products.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, i) => FadeSlideIn(index: i, playKey: 'pop-${products[i].id}', child: SizedBox(width: 140, child: ProductCard(products[i], badge: 'Terlaris'))),
        ),
      ),
    ]);
  }
}

// ======================= MENU =======================

class MenuTab extends ConsumerStatefulWidget {
  const MenuTab({super.key});

  @override
  ConsumerState<MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends ConsumerState<MenuTab> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  String _q = '';
  bool _favOnly = false;

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Beranda meminta fokus kolom cari; tab ini baru tampil pada frame yang sama, jadi fokus diminta sesudahnya.
    ref.listen(menuSearchFocusProvider, (prev, next) {
      if (next != prev) WidgetsBinding.instance.addPostFrameCallback((_) => _searchFocus.requestFocus());
    });
    final outlet = ref.watch(selectedOutletProvider);
    final selectedCat = ref.watch(menuCategoryProvider);
    final favorites = ref.watch(favoritesProvider);
    final menu = outlet == null ? null : ref.watch(menuProvider(outlet.id));
    final popular = outlet == null ? const <String>{} : (ref.watch(popularProvider(outlet.id)).value ?? const <String>[]).toSet();
    final all = menu?.value ?? const <Category>[];

    List<Category> visible() {
      final q = _q.trim().toLowerCase();
      bool match(Product p) => (q.isEmpty || p.name.toLowerCase().contains(q)) && (!_favOnly || favorites.contains(p.id));
      return [
        for (final c in all)
          if ((_favOnly || selectedCat == null || c.id == selectedCat) && c.products.any(match))
            Category(id: c.id, name: c.name, products: [for (final p in c.products) if (match(p)) p]),
      ];
    }

    Widget content() {
      if (outlet == null) return const EmptyState(icon: Icons.storefront_outlined, title: 'Belum ada outlet aktif');
      if (menu!.isLoading && !menu.hasValue) {
        return ListView(physics: const NeverScrollableScrollPhysics(), children: const [MenuSkeleton()]);
      }
      if (menu.hasError && !menu.hasValue) {
        return EmptyState(icon: Icons.cloud_off_rounded, title: 'Menu belum bisa dimuat', message: menu.error.toString(), actionLabel: 'Coba lagi', onAction: () => ref.invalidate(menuProvider(outlet.id)));
      }
      final cats = visible();
      return RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(menuProvider(outlet.id));
          await ref.read(menuProvider(outlet.id).future);
        },
        child: cats.isEmpty
            ? ListView(children: [
                const SizedBox(height: 48),
                _favOnly && favorites.isEmpty
                    ? const EmptyState(icon: Icons.favorite_border_rounded, title: 'Belum ada favorit', message: 'Ketuk ikon hati pada menu untuk menyimpannya di sini.')
                    : EmptyState(icon: Icons.search_off_rounded, title: 'Menu tidak ditemukan', message: _favOnly ? 'Tidak ada favoritmu yang cocok dengan pencarian.' : 'Coba kata kunci lain.'),
              ])
            : CustomScrollView(slivers: [
                ...productSections(context, cats, popularIds: popular, keyPrefix: 'menu-grid'),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ]),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () => pickOutlet(context, ref),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.store, size: 20),
              const SizedBox(width: 8),
              Flexible(child: Text(outlet?.name ?? 'Pilih outlet', overflow: TextOverflow.ellipsis)),
              const Icon(Icons.keyboard_arrow_down),
            ]),
          ),
        ),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _search,
            focusNode: _searchFocus,
            onChanged: (v) => setState(() => _q = v),
            decoration: InputDecoration(
              hintText: 'Cari menu…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _q.isEmpty ? null : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _search.clear(); _q = ''; })),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            _Chip(label: 'Semua', selected: !_favOnly && selectedCat == null, onTap: () {
              setState(() => _favOnly = false);
              ref.read(menuCategoryProvider.notifier).select(null);
            }),
            _Chip(label: 'Favorit', icon: Icons.favorite_rounded, selected: _favOnly, onTap: () => setState(() => _favOnly = true)),
            for (final c in all)
              _Chip(label: c.name, selected: !_favOnly && selectedCat == c.id, onTap: () {
                setState(() => _favOnly = false);
                ref.read(menuCategoryProvider.notifier).select(c.id);
              }),
          ]),
        ),
        Expanded(child: content()),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap, this.icon});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: ChoiceChip(
          avatar: icon == null ? null : Icon(icon, size: 16, color: selected ? const Color(0xFFE0573A) : const Color(0xFF50706C)),
          label: Text(label),
          showCheckmark: icon == null,
          selected: selected,
          onSelected: (_) => onTap(),
        ),
      );
}
