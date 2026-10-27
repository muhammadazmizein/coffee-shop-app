import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config.dart';
import '../state/providers.dart';
import '../widgets/illustration.dart';

/// Layar pembuka: logo muncul dengan animasi di atas latar espresso, biji kopi melayang pelan.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _intro =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();
  late final AnimationController _float =
      AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  static const _beans = [
    (0.12, 0.16, 1.0, -30.0, 0.0),
    (0.82, 0.12, 0.8, 25.0, 1.3),
    (0.08, 0.62, 0.9, 40.0, 2.1),
    (0.88, 0.58, 1.1, -20.0, 0.7),
    (0.24, 0.86, 0.7, 15.0, 3.0),
    (0.74, 0.84, 0.9, -45.0, 1.9),
  ];

  @override
  void initState() {
    super.initState();
    ref.read(welcomePromosProvider); // mulai memuat promo selagi splash tampil
    // Tahan sebentar supaya merek sempat terbaca, lalu serahkan ke router (login / onboarding / beranda).
    Future.delayed(const Duration(milliseconds: 1900), () {
      if (mounted) ref.read(splashDoneProvider.notifier).finish();
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _intro, curve: Curves.easeOutBack);
    final fade = CurvedAnimation(parent: _intro, curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
    final textFade = CurvedAnimation(parent: _intro, curve: const Interval(0.45, 1.0, curve: Curves.easeOut));
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0F766E), Color(0xFF063B38)]),
        ),
        child: LayoutBuilder(builder: (context, c) {
          return Stack(children: [
            for (final (x, y, scale, rot, phase) in _beans)
              AnimatedBuilder(
                animation: _float,
                builder: (_, child) {
                  final t = _float.value * 2 * math.pi + phase;
                  return Positioned(
                    left: c.maxWidth * x,
                    top: c.maxHeight * y + math.sin(t) * 8,
                    child: Opacity(opacity: 0.55, child: Transform.rotate(angle: rot * math.pi / 180 + math.sin(t) * .15, child: child)),
                  );
                },
                child: Illustration('bean', width: 34 * scale, height: 34 * scale),
              ),
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                FadeTransition(
                  opacity: fade,
                  child: ScaleTransition(scale: Tween(begin: 0.6, end: 1.0).animate(curve), child: const Illustration('logo', width: 120, height: 120)),
                ),
                const SizedBox(height: 24),
                FadeTransition(
                  opacity: textFade,
                  child: Column(children: [
                    Text(appName, style: const TextStyle(color: Color(0xFFF4FAF9), fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                    const SizedBox(height: 6),
                    Text('Kopi enak, dekat denganmu', style: TextStyle(color: const Color(0xFFF4FAF9).withValues(alpha: 0.7), fontSize: 14, letterSpacing: .4)),
                  ]),
                ),
              ]),
            ),
            Positioned(
              bottom: 56,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: textFade,
                child: const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF99F6E4)))),
              ),
            ),
          ]);
        }),
      ),
    );
  }
}
