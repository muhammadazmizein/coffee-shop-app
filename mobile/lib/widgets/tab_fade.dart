import 'package:flutter/material.dart';
import 'motion.dart';

/// IndexedStack dengan fade singkat saat tab berganti. State semua tab tetap terjaga (IndexedStack tidak diganti).
class TabFade extends StatefulWidget {
  const TabFade({super.key, required this.index, required this.children});
  final int index;
  final List<Widget> children;

  @override
  State<TabFade> createState() => _TabFadeState();
}

class _TabFadeState extends State<TabFade> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 240), value: 1);
  late final Animation<double> _opacity = Tween<double>(begin: 0.35, end: 1).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));

  @override
  void didUpdateWidget(TabFade old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index && !reduceMotion(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(opacity: _opacity, child: IndexedStack(index: widget.index, children: widget.children));
}
