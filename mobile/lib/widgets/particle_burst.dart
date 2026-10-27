import 'dart:math' as math;
import 'package:flutter/material.dart';

enum ParticleShape { rect, circle }

/// Ledakan partikel satu kali (confetti atau percikan koin) tanpa paket luar.
/// Fisika sederhana: kecepatan awal acak + gravitasi; memudar di akhir; berhenti dan membuang controllernya sendiri.
/// Tidak menampilkan apa pun bila perangkat meminta animasi dikurangi. Tidak menangkap sentuhan.
class ParticleBurst extends StatefulWidget {
  const ParticleBurst({
    super.key,
    this.origin = const Alignment(0, -0.35),
    this.count = 70,
    this.colors = const [Color(0xFF14B8A6), Color(0xFF0F766E), Color(0xFFF3C657), Color(0xFFE0573A), Color(0xFFFFFFFF)],
    this.duration = const Duration(milliseconds: 2400),
    this.minSpeed = 240,
    this.maxSpeed = 620,
    this.gravity = 900,
    this.size = 9,
    this.shape = ParticleShape.rect,
    this.spread = math.pi * 1.1,
    this.seed = 7,
    this.onDone,
  });

  /// Titik asal ledakan dalam koordinat Alignment (-1..1) pada area widget.
  final Alignment origin;
  final int count;
  final List<Color> colors;
  final Duration duration;
  final double minSpeed, maxSpeed, gravity, size, spread;
  final ParticleShape shape;
  final int seed;
  final VoidCallback? onDone;

  @override
  State<ParticleBurst> createState() => _ParticleBurstState();
}

class _P {
  _P(this.angle, this.speed, this.color, this.spin, this.size, this.phase);
  final double angle, speed, spin, size, phase;
  final Color color;
}

class _ParticleBurstState extends State<ParticleBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  late final List<_P> _ps;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final r = math.Random(widget.seed);
    _ps = List.generate(widget.count, (_) {
      // sudut: kerucut ke atas (-pi/2) dengan sebaran `spread`
      final a = -math.pi / 2 + (r.nextDouble() - .5) * widget.spread;
      return _P(a, widget.minSpeed + r.nextDouble() * (widget.maxSpeed - widget.minSpeed), widget.colors[r.nextInt(widget.colors.length)], (r.nextDouble() - .5) * 14, widget.size * (.6 + r.nextDouble() * .8), r.nextDouble() * math.pi * 2);
    });
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone?.call();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!MediaQuery.disableAnimationsOf(context)) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => _c.isDismissed || _c.isCompleted ? const SizedBox.expand() : CustomPaint(size: Size.infinite, painter: _BurstPainter(_ps, _c.value, widget)),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.ps, this.t, this.w);
  final List<_P> ps;
  final double t;
  final ParticleBurst w;

  @override
  void paint(Canvas canvas, Size size) {
    final o = Offset((w.origin.x + 1) / 2 * size.width, (w.origin.y + 1) / 2 * size.height);
    final secs = t * w.duration.inMilliseconds / 1000;
    final fade = t < .7 ? 1.0 : (1 - (t - .7) / .3).clamp(0.0, 1.0);
    for (final p in ps) {
      // posisi = asal + v*t + 1/2 g t^2, dengan hambatan udara sederhana pada v
      final drag = 1 / (1 + 1.6 * secs);
      final dx = math.cos(p.angle) * p.speed * secs * drag;
      final dy = math.sin(p.angle) * p.speed * secs * drag + .5 * w.gravity * secs * secs;
      final pos = o + Offset(dx, dy);
      if (pos.dy > size.height + 30 || pos.dx < -30 || pos.dx > size.width + 30) continue;
      final paint = Paint()..color = p.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.phase + p.spin * secs);
      if (w.shape == ParticleShape.circle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        // kepingan yang "berputar" di sumbu lain: lebar mengecil-membesar
        final flip = (math.cos(p.phase + p.spin * secs * 2)).abs().clamp(.25, 1.0);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.size * flip, height: p.size * 1.6), const Radius.circular(1.5)), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}
