import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/models.dart';
import '../state/providers.dart';
import '../widgets/illustration.dart';

/// Slide bawaan, dipakai bila admin belum membuat promo atau server tidak terjangkau.
final _fallback = [
  PromoSlide(title: 'Semua Favoritmu dalam Satu Aplikasi', body: 'Praktis pesan kopi, minuman segar, dan camilan favoritmu kapan saja.', art: 'onboarding_1'),
  PromoSlide(title: 'Diantar ke Pintu atau Ambil Sendiri', body: 'Pilih ambil di outlet, atau diantar langsung oleh kurir kami.', art: 'onboarding_2'),
  PromoSlide(title: 'Setiap Pesanan Ada Poinnya', body: 'Kumpulkan poin tiap belanja, lalu tukar jadi potongan harga.', art: 'onboarding_3'),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Router yang memilih tujuan: beranda bila sudah login, layar login bila belum.
  void _finish() {
    ref.read(welcomeSeenProvider.notifier).done();
    context.go('/');
  }

  void _next(int count) {
    if (_index >= count - 1) {
      _finish();
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    }
  }

  void _useVoucher(PromoSlide s) {
    ref.read(pendingVoucherProvider.notifier).set(s.voucherCode);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Kode ${s.voucherCode} akan dipakai di checkout')));
  }

  @override
  Widget build(BuildContext context) {
    final promos = ref.watch(welcomePromosProvider);
    if (promos.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final slides = (promos.value ?? const <PromoSlide>[]).isEmpty ? _fallback : promos.value!;
    final theme = Theme.of(context);
    final last = _index >= slides.length - 1;
    final loggedIn = ref.watch(authProvider).value != null;

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: slides.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => _SlideView(slide: slides[i], onCta: () => _useVoucher(slides[i])),
            ),
          ),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < slides.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _index ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _index ? theme.colorScheme.primary : theme.colorScheme.primary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: FilledButton(onPressed: () => _next(slides.length), child: Text(last ? (loggedIn ? 'Mulai' : 'Masuk') : 'Lanjut')),
          ),
          SizedBox(height: 48, child: last ? null : TextButton(onPressed: _finish, child: const Text('Lewati tahap ini'))),
        ]),
      ),
    );
  }
}

/// Kunci ilustrasi yang boleh dikirim server (sama dengan daftar di backend). Kunci lain -> gambar bawaan,
/// supaya app versi lama tidak error bila admin memakai ilustrasi yang baru ditambahkan.
const _knownArt = {
  'onboarding_1', 'onboarding_2', 'onboarding_3', 'product_latte', 'product_matcha',
  'product_chocolate', 'product_croissant', 'product_donut', 'product_boba',
};

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide, required this.onCta});
  final PromoSlide slide;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = ProductImage.resolve(slide.imageUrl);
    final art = Illustration(_knownArt.contains(slide.art) ? slide.art! : 'onboarding_1', fit: BoxFit.contain);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: url == null
                ? art
                : ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: SizedBox.expand(
                      child: Image.network(url, fit: BoxFit.cover, loadingBuilder: (_, child, p) => p == null ? child : art, errorBuilder: (_, _, _) => art),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Text(slide.title, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF0B2E2B))),
        const SizedBox(height: 10),
        Text(slide.body, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge?.copyWith(color: const Color(0xFF50706C))),
        if (slide.voucherCode != null) ...[
          const SizedBox(height: 14),
          FilledButton.tonal(onPressed: onCta, style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), child: Text(slide.ctaLabel ?? 'Pakai voucher ${slide.voucherCode}')),
        ],
      ]),
    );
  }
}
