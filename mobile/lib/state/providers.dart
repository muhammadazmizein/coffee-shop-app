import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api.dart';
import '../models/models.dart';

final apiProvider = Provider<Api>((ref) {
  return Api(onUnauthorized: () => ref.read(authProvider.notifier).signOut());
});

// ---------- Splash & onboarding ----------

/// true setelah animasi splash selesai (durasi minimum agar merek sempat terlihat).
class SplashDone extends Notifier<bool> {
  @override
  bool build() => false;
  void finish() => state = true;
}

final splashDoneProvider = NotifierProvider<SplashDone, bool>(SplashDone.new);

/// Slide welcome dari server. Gagal/lambat (>3 dtk) = daftar kosong, app memakai slide bawaan.
final welcomePromosProvider = FutureProvider<List<PromoSlide>>((ref) async {
  try {
    return await ref
        .read(apiProvider)
        .get('/promos/welcome', (d) => (d as List).map((p) => PromoSlide.fromJson(p)).toList())
        .timeout(const Duration(seconds: 3));
  } catch (_) {
    return const <PromoSlide>[];
  }
});

/// true setelah layar welcome dilewati pada pembukaan app ini. Sengaja tidak disimpan permanen:
/// welcome tampil setiap kali app dibuka (cold start), tidak berulang saat berpindah layar.
class WelcomeSeen extends Notifier<bool> {
  @override
  bool build() => false;
  void done() => state = true;
}

final welcomeSeenProvider = NotifierProvider<WelcomeSeen, bool>(WelcomeSeen.new);

// ---------- Navigasi beranda ----------

/// Tab aktif di HomeShell: 0 Beranda, 1 Menu, 2 Member, 3 Merch, 4 Saya.
class ShellTab extends Notifier<int> {
  @override
  int build() => 0;
  void go(int i) => state = i;
}

final shellTabProvider = NotifierProvider<ShellTab, int>(ShellTab.new);

/// Kategori yang difilter di tab Menu (null = semua).
class MenuCategory extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = id;
}

final menuCategoryProvider = NotifierProvider<MenuCategory, String?>(MenuCategory.new);

/// Kode voucher yang dipilih dari beranda; dipakai otomatis di checkout.
class PendingVoucher extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? code) => state = code;
}

final pendingVoucherProvider = NotifierProvider<PendingVoucher, String?>(PendingVoucher.new);

// ---------- Auth ----------

class AuthNotifier extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    if (await readToken() == null) return null;
    try {
      return await _fetchMe();
    } on ApiException catch (e) {
      if (e.statusCode == 401) await saveToken(null);
      return null;
    }
  }

  Future<UserProfile> _fetchMe() =>
      ref.read(apiProvider).get('/me', (d) => UserProfile.fromJson(d), auth: true);

  Future<String?> requestOtp(String phone) => ref.read(apiProvider).post(
        '/auth/otp/request',
        {'phone': phone},
        (d) => d['devCode'] as String?,
      );

  Future<void> verifyOtp(String phone, String code) async {
    final res = await ref.read(apiProvider).post(
          '/auth/otp/verify',
          {'phone': phone, 'code': code},
          (d) => d as Map<String, dynamic>,
        );
    await saveToken(res['token'] as String);
    state = AsyncData(await _fetchMe());
  }

  Future<void> updateName(String name) => updateProfile({'name': name});

  /// Ubah data profil (name, email, birthDate 'YYYY-MM-DD', gender). Hanya field yang diisi yang dikirim.
  Future<void> updateProfile(Map<String, dynamic> fields) async {
    final user = await ref.read(apiProvider).patch('/me', fields, (d) => UserProfile.fromJson(Map<String, dynamic>.from(d as Map)), auth: true);
    state = AsyncData(user);
  }

  Future<void> refreshProfile() async {
    try {
      state = AsyncData(await _fetchMe());
    } on ApiException catch (_) {}
  }

  Future<void> signOut() async {
    await saveToken(null);
    state = const AsyncData(null);
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, UserProfile?>(AuthNotifier.new);

// ---------- Outlet & menu ----------

final outletsProvider = FutureProvider<List<Outlet>>((ref) {
  return ref.read(apiProvider).get('/outlets', (d) => (d as List).map((o) => Outlet.fromJson(o)).toList());
});

class SelectedOutlet extends Notifier<Outlet?> {
  @override
  Outlet? build() => null;
  void select(Outlet outlet) => state = outlet;
}

final selectedOutletProvider = NotifierProvider<SelectedOutlet, Outlet?>(SelectedOutlet.new);

final menuProvider = FutureProvider.family<List<Category>, String>((ref, outletId) {
  return ref.read(apiProvider).get(
        '/menu',
        (d) => (d as List).map((c) => Category.fromJson(c)).toList(),
        query: {'outletId': outletId},
      );
});

final popularProvider = FutureProvider.family<List<String>, String>((ref, outletId) {
  return ref.read(apiProvider).get(
        '/menu/popular',
        (d) => (d as List).cast<String>(),
        query: {'outletId': outletId},
      );
});

final checkInProvider = FutureProvider<CheckInView>((ref) {
  return ref.read(apiProvider).get('/me/checkin', (d) => CheckInView.fromJson(Map<String, dynamic>.from(d as Map)), auth: true);
});

final inboxProvider = FutureProvider<Inbox>((ref) {
  return ref.read(apiProvider).get('/me/notifications', (d) => Inbox.fromJson(Map<String, dynamic>.from(d as Map)), auth: true);
});

final membershipProvider = FutureProvider<Membership>((ref) {
  return ref.read(apiProvider).get('/me/membership', (d) => Membership.fromJson(Map<String, dynamic>.from(d as Map)), auth: true);
});

final pointsHistoryProvider = FutureProvider<List<PointEntry>>((ref) {
  return ref.read(apiProvider).get('/me/points', (d) => (d as List).map((e) => PointEntry.fromJson(e)).toList(), auth: true);
});

final activeVouchersProvider = FutureProvider<List<VoucherView>>((ref) {
  return ref.read(apiProvider).get('/vouchers/active', (d) => (d as List).map((v) => VoucherView.fromJson(v)).toList(), auth: true);
});

final payMethodsProvider = FutureProvider<List<PayMethod>>((ref) {
  return ref.read(apiProvider).get('/payments/methods', (d) => (d as List).map((m) => PayMethod.fromJson(m)).toList(), auth: true);
});

/// Pesanan yang sedang dibayar; dipakai untuk kembali ke halaman bayar setelah membuka aplikasi e-wallet.
class LastPayOrder extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? id) => state = id;
}

final lastPayOrderProvider = NotifierProvider<LastPayOrder, String?>(LastPayOrder.new);

// ---------- Cart ----------

class CartLine {
  CartLine({required this.product, required this.options, required this.qty, this.note});
  final Product product;
  final List<Option> options;
  final int qty;
  final String? note;

  int get unitPrice => product.price + options.fold(0, (s, o) => s + o.extraPrice);
  int get total => unitPrice * qty;

  CartLine copyWith({int? qty}) =>
      CartLine(product: product, options: options, qty: qty ?? this.qty, note: note);

  Map<String, dynamic> toOrderJson() => {
        'productId': product.id,
        'qty': qty,
        'optionIds': options.map((o) => o.id).toList(),
        if (note != null && note!.isNotEmpty) 'note': note,
      };
}

class Cart extends Notifier<List<CartLine>> {
  @override
  List<CartLine> build() => [];

  void add(CartLine line) {
    // Baris identik (produk + opsi + catatan sama) digabung.
    final i = state.indexWhere((l) =>
        l.product.id == line.product.id &&
        l.note == line.note &&
        _sameOptions(l.options, line.options));
    if (i >= 0) {
      state = [...state]..[i] = state[i].copyWith(qty: state[i].qty + line.qty);
    } else {
      state = [...state, line];
    }
  }

  bool _sameOptions(List<Option> a, List<Option> b) {
    final x = a.map((o) => o.id).toSet(), y = b.map((o) => o.id).toSet();
    return x.length == y.length && x.containsAll(y);
  }

  void setQty(int index, int qty) {
    if (qty <= 0) {
      state = [...state]..removeAt(index);
    } else {
      state = [...state]..[index] = state[index].copyWith(qty: qty.clamp(1, 20));
    }
  }

  /// Mengembalikan baris yang baru dihapus ke posisi semula (untuk "Urungkan").
  void insert(int index, CartLine line) {
    final i = index.clamp(0, state.length);
    state = [...state]..insert(i, line);
  }

  void clear() => state = [];
}

final cartProvider = NotifierProvider<Cart, List<CartLine>>(Cart.new);

final cartSubtotalProvider = Provider<int>((ref) => ref.watch(cartProvider).fold(0, (s, l) => s + l.total));
final cartCountProvider = Provider<int>((ref) => ref.watch(cartProvider).fold(0, (s, l) => s + l.qty));

// ---------- Alamat & pesanan ----------

final addressesProvider = FutureProvider<List<Address>>((ref) {
  return ref.read(apiProvider).get('/addresses', (d) => (d as List).map((a) => Address.fromJson(a)).toList(), auth: true);
});

final ordersProvider = FutureProvider<List<OrderView>>((ref) {
  return ref.read(apiProvider).get('/orders', (d) => (d as List).map((o) => OrderView.fromJson(o)).toList(), auth: true);
});

final orderProvider = FutureProvider.family<OrderView, String>((ref, id) {
  return ref.read(apiProvider).get('/orders/$id', (d) => OrderView.fromJson(d), auth: true);
});

/// "Order Lagi": masukkan isi pesanan lama ke keranjang memakai menu outlet yang sedang dipilih.
/// Item yang sudah tidak tersedia, atau opsi wajibnya sudah berubah, dilewati. Mengembalikan pesan untuk pengguna.
Future<({int added, int skipped})> reorder(WidgetRef ref, OrderView order) async {
  final outlet = ref.read(selectedOutletProvider);
  if (outlet == null) return (added: 0, skipped: order.items.length);
  final categories = await ref.read(menuProvider(outlet.id).future);
  final products = {for (final c in categories) for (final p in c.products) p.id: p};
  var added = 0, skipped = 0;
  for (final item in order.items) {
    final product = products[item.productId];
    if (product == null) {
      skipped++;
      continue;
    }
    final options = [
      for (final g in product.groups)
        for (final o in g.options)
          if (item.optionIds.contains(o.id)) o,
    ];
    final valid = product.groups.every((g) {
      final n = options.where((o) => g.options.any((x) => x.id == o.id)).length;
      return (!g.required || n > 0) && n <= g.maxSelect;
    });
    if (!valid) {
      skipped++;
      continue;
    }
    ref.read(cartProvider.notifier).add(CartLine(product: product, options: options, qty: item.qty, note: item.note));
    added++;
  }
  return (added: added, skipped: skipped);
}
