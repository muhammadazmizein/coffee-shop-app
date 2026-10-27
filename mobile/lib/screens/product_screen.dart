import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/format.dart';
import '../models/models.dart';
import '../state/providers.dart';
import '../widgets/animated_number.dart';
import '../widgets/haptics.dart';
import '../widgets/hero_tags.dart';
import '../widgets/illustration.dart';
import '../widgets/option_chips.dart';
import '../widgets/qty_stepper.dart';
import '../widgets/section_card.dart';

class ProductScreen extends ConsumerStatefulWidget {
  const ProductScreen({super.key, required this.product});
  final Product product;

  @override
  ConsumerState<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends ConsumerState<ProductScreen> {
  final Map<String, Set<String>> _selected = {}; // groupId -> optionIds
  final Set<String> _warn = {}; // grup yang baru melewati batas pilihan
  Timer? _warnTimer;
  final _note = TextEditingController();
  bool _showNote = false;
  bool _adding = false; // umpan balik singkat "Ditambahkan" sebelum layar menutup
  final _scroll = ScrollController();
  int _qty = 1;

  @override
  void initState() {
    super.initState();
    // Grup wajib pilih satu: default ke opsi pertama agar pelanggan tidak lupa memilih.
    for (final g in widget.product.groups) {
      _selected[g.id] = {if (g.required && g.maxSelect == 1 && g.options.isNotEmpty) g.options.first.id};
    }
  }

  @override
  void dispose() {
    _warnTimer?.cancel();
    _scroll.dispose();
    _note.dispose();
    super.dispose();
  }

  List<Option> get _chosen => [
        for (final g in widget.product.groups)
          for (final o in g.options)
            if (_selected[g.id]!.contains(o.id)) o,
      ];

  int get _unit => widget.product.price + _chosen.fold(0, (s, o) => s + o.extraPrice);

  bool get _valid => widget.product.groups.every((g) => !g.required || _selected[g.id]!.isNotEmpty);

  void _toggle(OptionGroup g, Option o) {
    final set = _selected[g.id]!;
    setState(() {
      if (g.maxSelect == 1) {
        set
          ..clear()
          ..add(o.id);
      } else if (set.contains(o.id)) {
        set.remove(o.id);
      } else if (set.length < g.maxSelect) {
        set.add(o.id);
      } else {
        // Melewati batas: getar ringan + pesan kecil yang hilang sendiri.
        successHaptic();
        _warn.add(g.id);
        _warnTimer?.cancel();
        _warnTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(_warn.clear);
        });
      }
    });
  }

  Future<void> _add() async {
    if (_adding) return;
    ref.read(cartProvider.notifier).add(CartLine(
          product: widget.product,
          options: _chosen,
          qty: _qty,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        ));
    successHaptic();
    final router = GoRouter.maybeOf(context);
    final navigator = Navigator.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${widget.product.name} ditambahkan ke keranjang'),
        action: SnackBarAction(label: 'Lihat keranjang', onPressed: () => router?.push('/cart')),
      ));
    // Tombol berubah jadi centang "Ditambahkan" sebentar, baru layar menutup (langsung bila animasi dikurangi).
    if (!MediaQuery.disableAnimationsOf(context)) {
      setState(() => _adding = true);
      await Future<void>.delayed(const Duration(milliseconds: 420));
      if (!mounted) return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final theme = Theme.of(context);
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: Stack(children: [
        CustomScrollView(controller: _scroll, slivers: [
          SliverToBoxAdapter(
            // Paralaks: saat digulir gambar bergeser lebih lambat, mengecil, dan memudar; saat ditarik ke bawah, membesar.
            child: AnimatedBuilder(
              animation: _scroll,
              builder: (_, _) {
                final off = _scroll.hasClients ? _scroll.offset : 0.0;
                final t = off.clamp(0.0, 260.0) / 260;
                final over = off < 0 ? -off : 0.0;
                return Container(
                  height: 250 + top,
                  padding: EdgeInsets.only(top: top + 16, bottom: 18),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFD3F3EE), Color(0xFFEAF8F5)]),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
                  ),
                  child: Center(
                    child: Opacity(
                      opacity: 1 - .7 * t,
                      child: Transform.translate(
                        offset: Offset(0, off.clamp(0.0, 260.0) * .4),
                        child: Transform.scale(scale: (1 - .16 * t) + over / 700, child: Hero(tag: productHeroTag(p.id), child: ProductImage(p, size: 216, radius: 108))),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 130),
            sliver: SliverList.list(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: kInk, height: 1.2)),
                  const SizedBox(height: 6),
                  Text(rupiah(p.price), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
                  if (p.description != null && p.description!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(p.description!, style: theme.textTheme.bodyMedium?.copyWith(color: kMuted, height: 1.45)),
                  ],
                ]),
              ),
              for (final g in p.groups) ...[
                const SizedBox(height: 16),
                OptionGroupCard(group: g, selected: _selected[g.id]!, warning: _warn.contains(g.id), onToggle: (o) => _toggle(g, o)),
              ],
              const SizedBox(height: 16),
              SectionCard(
                title: 'Catatan',
                icon: Icons.edit_note_rounded,
                trailing: TextButton(onPressed: () => setState(() => _showNote = !_showNote), child: Text(_showNote ? 'Tutup' : 'Tambah')),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.topCenter,
                  child: _showNote || _note.text.isNotEmpty
                      ? TextField(controller: _note, maxLength: 200, maxLines: 2, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'Mis. es sedikit, tanpa sedotan'))
                      : const Text('Opsional: pesan khusus untuk barista.', style: TextStyle(color: kMuted)),
                ),
              ),
            ]),
          ),
        ]),
        Positioned(
          top: top + 8,
          left: 12,
          child: Material(
            color: Colors.white,
            elevation: 3,
            shadowColor: Colors.black26,
            shape: const CircleBorder(),
            child: InkWell(customBorder: const CircleBorder(), onTap: () => Navigator.of(context).maybePop(), child: const SizedBox(width: 44, height: 44, child: Icon(Icons.arrow_back_rounded, color: kInk))),
          ),
        ),
      ]),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom * 0),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 14, offset: const Offset(0, -3))]),
        child: SafeArea(
          child: Row(children: [
            QtyStepper(value: _qty, onChanged: (v) => setState(() => _qty = v)),
            const SizedBox(width: 14),
            Expanded(
              child: FilledButton(
                onPressed: _valid ? _add : null,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
                  child: _adding
                      ? const Row(key: ValueKey('done'), mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check_circle_rounded, size: 22), SizedBox(width: 8), Text('Ditambahkan')])
                      : FittedBox(
                          key: const ValueKey('add'),
                          fit: BoxFit.scaleDown,
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Text('Tambah • '),
                            AnimatedNumber(value: _unit * _qty, format: rupiah, duration: const Duration(milliseconds: 450)),
                          ]),
                        ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
