import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/api.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../state/providers.dart';
import '../widgets/async_view.dart';
import '../widgets/entrance.dart';

final _dateFmt = DateFormat('d MMM yyyy, HH:mm', 'id_ID');

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'Baru saja';
  if (d.inMinutes < 60) return '${d.inMinutes} mnt lalu';
  if (d.inHours < 24) return '${d.inHours} jam lalu';
  if (d.inDays < 7) return '${d.inDays} hari lalu';
  return _dateFmt.format(t);
}

(IconData, Color) _look(String type) => switch (type) {
  'ORDER' => (Icons.receipt_long_rounded, brandColor),
  'POINTS' => (Icons.stars_rounded, const Color(0xFFD99A1E)),
  'CHECKIN' => (Icons.event_available_rounded, const Color(0xFF2F7A3E)),
  'LEVEL' => (Icons.workspace_premium_rounded, const Color(0xFF5B63C9)),
  'PROMO' => (Icons.campaign_rounded, const Color(0xFFC2563B)),
  _ => (Icons.notifications_rounded, brandColor),
};

class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  Future<void> _markAll(WidgetRef ref) async {
    try {
      await ref
          .read(apiProvider)
          .post('/me/notifications/read-all', null, (_) {}, auth: true);
    } on ApiException catch (_) {}
    ref.invalidate(inboxProvider);
    ref.read(authProvider.notifier).refreshProfile();
  }

  Future<void> _open(BuildContext context, WidgetRef ref, InboxItem it) async {
    if (!it.read) {
      ref
          .read(apiProvider)
          .post('/me/notifications/${it.id}/read', null, (_) {}, auth: true)
          .then((_) {
            ref.invalidate(inboxProvider);
            ref.read(authProvider.notifier).refreshProfile();
          })
          .catchError((_) {});
    }
    if (it.orderId != null) context.push('/orders/${it.orderId}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(inboxProvider);
    final unread = inbox.value?.unread ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kotak Masuk'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () => _markAll(ref),
              child: const Text('Tandai semua dibaca'),
            ),
        ],
      ),
      body: AsyncView<Inbox>(
        value: inbox,
        onRetry: () => ref.invalidate(inboxProvider),
        builder: (data) => RefreshIndicator(
          onRefresh: () => ref.refresh(inboxProvider.future),
          child: data.items.isEmpty
              ? ListView(
                  children: [
                    const SizedBox(height: 120),
                    Icon(
                      Icons.inbox_outlined,
                      size: 72,
                      color: Colors.black.withValues(alpha: .25),
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: Text(
                        'Belum ada pesan',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'Kabar pesanan, poin, dan promo akan muncul di sini.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: data.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final it = data.items[i];
                    final (icon, color) = _look(it.type);
                    // Kunci per id: pesan baru yang datang belakangan masuk berundak, pesan lama tidak mengulang animasi.
                    return FadeSlideIn(
                      key: ValueKey(it.id),
                      delay: Duration(milliseconds: 60 * (i > 7 ? 0 : i)),
                      child: Material(
                        animationDuration: const Duration(milliseconds: 320),
                        color: it.read ? Colors.white : const Color(0xFFEAF8F5),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _open(context, ref, it),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFD5EBE8),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: .12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(icon, color: color, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              it.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: it.read
                                                    ? FontWeight.w600
                                                    : FontWeight.w800,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          // Titik belum-dibaca memudar saat pesan ditandai dibaca.
                                          AnimatedOpacity(
                                            duration: const Duration(
                                              milliseconds: 320,
                                            ),
                                            opacity: it.read ? 0 : 1,
                                            child: Container(
                                              width: 9,
                                              height: 9,
                                              margin: const EdgeInsets.only(
                                                left: 8,
                                              ),
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFD33F3F),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        it.body,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(height: 1.3),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _ago(it.createdAt),
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
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
