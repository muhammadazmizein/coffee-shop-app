import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../models/models.dart';
import 'illustration.dart';
import 'outlet_picker.dart';
import 'pressable.dart';

const _border = Color(0xFFD5EBE8);
const _muted = Color(0xFF50706C);

/// Tautan rute Google Maps ke outlet: pakai koordinat bila ada, jika tidak pakai alamat.
Uri directionsUri(Outlet o) {
  if (o.lat != null && o.lng != null) {
    return Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${o.lat},${o.lng}');
  }
  return Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': o.address});
}

/// tel:+62... dari nomor lokal (08...) atau internasional; null bila kosong/tidak valid.
Uri? telUri(String? phone) {
  if (phone == null) return null;
  var d = phone.replaceAll(RegExp(r'\D'), '');
  if (d.isEmpty) return null;
  if (d.startsWith('0')) d = '62${d.substring(1)}';
  if (d.length < 8) return null;
  return Uri(scheme: 'tel', path: '+$d');
}

Future<void> _open(BuildContext context, Uri uri, String failMessage) async {
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(failMessage)));
  }
}

/// Footer beranda: merek, kartu outlet (jam, rute, telepon), cara pesan, dan versi.
class HomeFooter extends StatelessWidget {
  const HomeFooter({super.key, required this.outlet});
  final Outlet? outlet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
      child: Column(children: [
        const Illustration('logo', width: 56, height: 56),
        const SizedBox(height: 10),
        Text(appName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: inkColor)),
        const SizedBox(height: 2),
        Text('Kopi enak, dekat denganmu', textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: _muted)),
        const SizedBox(height: 22),
        if (outlet != null) _OutletCard(outlet: outlet!),
        if (outlet != null) const SizedBox(height: 14),
        const _HowToOrder(),
        const SizedBox(height: 22),
        Text('$appName • v1.0', style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF7C9692))),
      ]),
    );
  }
}

class _OutletCard extends StatelessWidget {
  const _OutletCard({required this.outlet});
  final Outlet outlet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final open = outletOpenNow(outlet);
    final tel = telUri(outlet.phone);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: _border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: brandColor.withValues(alpha: .1), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.storefront_rounded, color: brandColor)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Outlet kami', style: theme.textTheme.labelMedium?.copyWith(color: brandColor, fontWeight: FontWeight.w700)),
              Text(outlet.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.2)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Text(outlet.address, maxLines: 3, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: _muted, height: 1.35)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 6, children: [
          _Chip(icon: open ? Icons.check_circle_rounded : Icons.schedule_rounded, text: open ? 'Buka sekarang' : 'Sedang tutup', ok: open),
          _Chip(icon: Icons.access_time_rounded, text: 'Hari ini ${hourLabel(outlet.openHour)} - ${hourLabel(outlet.closeHour)}', ok: null),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: Pressable(
              child: OutlinedButton.icon(
                onPressed: () => _open(context, directionsUri(outlet), 'Tidak bisa membuka peta di HP ini.'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46), padding: const EdgeInsets.symmetric(horizontal: 10), side: const BorderSide(color: brandColor, width: 1.4)),
                icon: const Icon(Icons.directions_rounded, size: 19),
                label: const Text('Rute', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
          if (tel != null) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Pressable(
                child: FilledButton.icon(
                  onPressed: () => _open(context, tel, 'Tidak bisa membuka aplikasi telepon di HP ini.'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 46), padding: const EdgeInsets.symmetric(horizontal: 10)),
                  icon: const Icon(Icons.call_rounded, size: 19),
                  label: const Text('Telepon', maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text, required this.ok});
  final IconData icon;
  final String text;
  final bool? ok; // true hijau, false abu, null netral

  @override
  Widget build(BuildContext context) {
    final color = ok == null ? _muted : (ok! ? const Color(0xFF2F7A3E) : const Color(0xFF6B8985));
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

class _HowToOrder extends StatelessWidget {
  const _HowToOrder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      decoration: BoxDecoration(color: const Color(0xFFE5F6F3), borderRadius: BorderRadius.circular(22)),
      child: Column(children: [
        Text('Cara pesan', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: inkColor)),
        const SizedBox(height: 14),
        const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _Step(icon: Icons.menu_book_rounded, label: 'Pilih menu')),
          _Dash(),
          Expanded(child: _Step(icon: Icons.payments_rounded, label: 'Bayar')),
          _Dash(),
          Expanded(child: _Step(icon: Icons.takeout_dining_rounded, label: 'Ambil / Diantar')),
        ]),
      ]),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(width: 48, height: 48, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(icon, color: brandColor, size: 24)),
      const SizedBox(height: 8),
      Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: inkColor, height: 1.25)),
    ]);
  }
}

class _Dash extends StatelessWidget {
  const _Dash();

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(top: 23), child: SizedBox(width: 14, child: Divider(height: 2, thickness: 2, color: brandColor.withValues(alpha: .35))));
}
