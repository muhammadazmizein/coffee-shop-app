import 'dart:math' as math;
import 'package:flutter/material.dart';

const _teal = Color(0xFF0F766E);
const _red = Color(0xFFC2563B);
const _grey = Color(0xFFDDE9E7);

/// Tonggak (0-3) yang sudah dicapai sebuah status; -1 bila belum ada (menunggu bayar, batal, kedaluwarsa).
int milestoneOf(String status, String type) => switch (status) {
      'PAID' => 0,
      'PREPARING' => 1,
      'READY' => type == 'PICKUP' ? 2 : 1,
      'ON_DELIVERY' => 2,
      'COMPLETED' => 3,
      _ => -1,
    };

List<String> trackerLabels(String type) => ['Dibayar', 'Diproses', type == 'PICKUP' ? 'Siap diambil' : 'Diantar', 'Selesai'];

/// Pelacak 4 langkah: selesai = teal + centang, berjalan = berdenyut, belum = abu. Pesanan batal/kedaluwarsa
/// menampilkan langkah yang sempat tercapai lalu satu simpul merah di titik berhentinya.
class OrderTracker extends StatelessWidget {
  const OrderTracker({super.key, required this.status, required this.type, this.eventStatuses = const []});
  final String status, type;
  final List<String> eventStatuses;

  @override
  Widget build(BuildContext context) {
    final failed = status == 'CANCELLED' || status == 'EXPIRED';
    final completed = status == 'COMPLETED';
    final labels = trackerLabels(type);
    final reached = failed ? eventStatuses.fold<int>(-1, (m, s) => math.max(m, milestoneOf(s, type))) : milestoneOf(status, type);
    final failedAt = failed ? math.min(reached + 1, 3) : -1;

    _NodeState stateOf(int i) {
      if (failed) return i <= reached ? _NodeState.done : (i == failedAt ? _NodeState.failed : _NodeState.pending);
      if (completed) return _NodeState.done;
      if (i < reached) return _NodeState.done;
      if (i == reached) return _NodeState.active;
      return _NodeState.pending;
    }

    bool lineOn(int i) => stateOf(i) == _NodeState.done || stateOf(i) == _NodeState.active; // garis menuju simpul i dari kiri
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < 4; i++)
        Expanded(
          child: Column(children: [
            SizedBox(
              height: 40,
              child: Stack(alignment: Alignment.center, children: [
                Row(children: [
                  Expanded(child: _Bar(seq: 2 * i - 1, color: i == 0 ? Colors.transparent : (stateOf(i) == _NodeState.failed ? _red : (lineOn(i) ? _teal : _grey)))),
                  Expanded(child: _Bar(seq: 2 * i, color: i == 3 ? Colors.transparent : (stateOf(i + 1) == _NodeState.failed ? _red : (stateOf(i) == _NodeState.done && lineOn(i + 1) ? _teal : _grey)))),
                ]),
                _Node(state: stateOf(i)),
              ]),
            ),
            const SizedBox(height: 6),
            Text(
              stateOf(i) == _NodeState.failed ? (status == 'EXPIRED' ? 'Kedaluwarsa' : 'Dibatalkan') : labels[i],
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, height: 1.2, fontWeight: stateOf(i) == _NodeState.pending ? FontWeight.w500 : FontWeight.w800, color: switch (stateOf(i)) { _NodeState.pending => const Color(0xFF8AA09D), _NodeState.failed => _red, _ => const Color(0xFF0B2E2B) }),
            ),
          ]),
        ),
    ]);
  }
}

enum _NodeState { done, active, pending, failed }

class _Node extends StatefulWidget {
  const _Node({required this.state});
  final _NodeState state;

  @override
  State<_Node> createState() => _NodeViewState();
}

class _NodeViewState extends State<_Node> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  bool get _pulse => widget.state == _NodeState.active && !MediaQuery.disableAnimationsOf(context);

  void _sync() {
    if (_pulse) {
      if (!_c.isAnimating) _c.repeat();
    } else if (_c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_Node old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Saat sebuah simpul berganti keadaan (mis. aktif -> selesai) tampilannya membal masuk.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 480),
      switchInCurve: Curves.elasticOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
      child: KeyedSubtree(key: ValueKey(widget.state), child: _body()),
    );
  }

  Widget _body() {
    switch (widget.state) {
      case _NodeState.done:
        return _dot(_teal, const Icon(Icons.check_rounded, size: 20, color: Colors.white));
      case _NodeState.failed:
        return _dot(_red, const Icon(Icons.close_rounded, size: 20, color: Colors.white));
      case _NodeState.pending:
        return _dot(_grey, Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFB4C7C4), shape: BoxShape.circle)));
      case _NodeState.active:
        return AnimatedBuilder(
          animation: _c,
          builder: (_, _) => Stack(alignment: Alignment.center, children: [
            Container(width: 34 + 12 * _c.value, height: 34 + 12 * _c.value, decoration: BoxDecoration(shape: BoxShape.circle, color: _teal.withValues(alpha: .25 * (1 - _c.value)))),
            Container(width: 34, height: 34, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.all(color: _teal, width: 3.5)), child: Center(child: Container(width: 12, height: 12, decoration: const BoxDecoration(color: _teal, shape: BoxShape.circle)))),
          ]),
        );
    }
  }

  Widget _dot(Color color, Widget child) => Container(width: 34, height: 34, decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: Center(child: child));
}

/// Potongan garis penghubung yang terisi dari kiri ke kanan saat berubah dari abu ke berwarna
/// (pada tampilan pertama dan setiap status berubah). `seq` mengurutkan potongan agar mengisi berantai.
class _Bar extends StatefulWidget {
  const _Bar({required this.color, required this.seq});
  final Color color;
  final int seq;

  @override
  State<_Bar> createState() => _BarState();
}

class _BarState extends State<_Bar> with SingleTickerProviderStateMixin {
  static const _stepMs = 170, _fillMs = 300;
  late final AnimationController _c = AnimationController(vsync: this, duration: Duration(milliseconds: math.max(widget.seq, 0) * _stepMs + _fillMs));
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: Interval(math.max(widget.seq, 0) * _stepMs / _c.duration!.inMilliseconds, 1, curve: Curves.easeOutCubic));
  bool _started = false;

  bool get _plain => widget.color == _grey || widget.color == Colors.transparent;

  void _run() {
    if (_plain) {
      _c.value = 0;
    } else if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else {
      _c.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _run();
  }

  @override
  void didUpdateWidget(_Bar old) {
    super.didUpdateWidget(old);
    if (old.color != widget.color) _run();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.color == Colors.transparent) return const SizedBox(height: 4);
    return SizedBox(
      height: 4,
      child: Stack(fit: StackFit.expand, children: [
        const ColoredBox(color: _grey),
        AnimatedBuilder(
          animation: _t,
          builder: (_, _) => FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: _plain ? 0 : _t.value, child: ColoredBox(color: widget.color)),
        ),
      ]),
    );
  }
}
