class Outlet {
  Outlet({
    required this.id,
    required this.name,
    required this.address,
    required this.openHour,
    required this.closeHour,
    required this.deliveryRadiusKm,
    this.lat,
    this.lng,
    this.phone,
  });
  final String id, name, address;
  final int openHour, closeHour;

  /// Koordinat dan telepon outlet (footer beranda: tombol Rute dan Telepon). Bisa kosong bila server belum mengirimnya.
  final double? lat, lng;
  final String? phone;

  /// Jarak maksimum pengantaran dari outlet; 0 berarti delivery dimatikan.
  final double deliveryRadiusKm;

  factory Outlet.fromJson(Map<String, dynamic> j) => Outlet(
        id: j['id'],
        name: j['name'],
        address: j['address'],
        openHour: j['openHour'],
        closeHour: j['closeHour'],
        // Server mengirim Decimal sebagai string ("1" atau "1.5").
        deliveryRadiusKm: double.tryParse('${j['deliveryRadiusKm']}') ?? 0,
        lat: j['lat'] == null ? null : double.tryParse('${j['lat']}'),
        lng: j['lng'] == null ? null : double.tryParse('${j['lng']}'),
        phone: j['phone'] == null || '${j['phone']}'.trim().isEmpty ? null : '${j['phone']}'.trim(),
      );
}

class Option {
  Option({required this.id, required this.name, required this.extraPrice});
  final String id, name;
  final int extraPrice;

  factory Option.fromJson(Map<String, dynamic> j) =>
      Option(id: j['id'], name: j['name'], extraPrice: j['extraPrice']);
}

class OptionGroup {
  OptionGroup({required this.id, required this.name, required this.required, required this.maxSelect, required this.options});
  final String id, name;
  final bool required;
  final int maxSelect;
  final List<Option> options;

  factory OptionGroup.fromJson(Map<String, dynamic> j) => OptionGroup(
        id: j['id'],
        name: j['name'],
        required: j['required'],
        maxSelect: j['maxSelect'],
        options: (j['options'] as List).map((o) => Option.fromJson(o)).toList(),
      );
}

class Product {
  Product({required this.id, required this.name, required this.price, this.description, this.imageUrl, this.categoryName, required this.groups});
  final String id, name;
  final String? categoryName;
  final int price;
  final String? description, imageUrl;
  final List<OptionGroup> groups;

  factory Product.fromJson(Map<String, dynamic> j, {String? categoryName}) => Product(
        categoryName: categoryName,
        id: j['id'],
        name: j['name'],
        price: j['price'],
        description: j['description'],
        imageUrl: j['imageUrl'],
        groups: (j['optionGroups'] as List).map((g) => OptionGroup.fromJson(g)).toList(),
      );
}

class Category {
  Category({required this.id, required this.name, required this.products});
  final String id, name;
  final List<Product> products;

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'],
        name: j['name'],
        products: (j['products'] as List).map((p) => Product.fromJson(p, categoryName: j['name'])).toList(),
      );
}

class Address {
  Address({required this.id, required this.label, required this.recipient, required this.detail});
  final String id, label, recipient, detail;

  factory Address.fromJson(Map<String, dynamic> j) =>
      Address(id: j['id'], label: j['label'], recipient: j['recipient'], detail: j['detail']);
}

class UserProfile {
  UserProfile({
    required this.id,
    required this.phone,
    this.name,
    required this.points,
    this.email,
    this.birthDate,
    this.gender,
    this.unread = 0,
    this.completionPercent = 0,
    this.missing = const [],
  });
  final String id, phone;
  final String? name, email, birthDate, gender; // birthDate: YYYY-MM-DD
  final int points, unread, completionPercent;
  final List<String> missing; // name | email | birthDate | gender | address

  bool get isComplete => completionPercent >= 100;

  factory UserProfile.fromJson(Map<String, dynamic> j) {
    final c = j['profileCompletion'] as Map?;
    return UserProfile(
      id: j['id'],
      phone: j['phone'],
      name: j['name'],
      points: j['points'],
      email: j['email'],
      birthDate: j['birthDate'],
      gender: j['gender'],
      unread: j['unreadNotifications'] ?? 0,
      completionPercent: (c?['percent'] ?? 0) as int,
      missing: ((c?['missing'] as List?) ?? const []).cast<String>(),
    );
  }
}

class OrderItemView {
  OrderItemView({
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.options,
    this.productId,
    this.optionIds = const [],
    this.note,
  });
  final String name;
  final int qty, unitPrice;
  final List<String> options;
  final String? productId, note;
  final List<String> optionIds;

  factory OrderItemView.fromJson(Map<String, dynamic> j) {
    final opts = (j['options'] as List?) ?? [];
    return OrderItemView(
      name: j['name'],
      qty: j['qty'],
      unitPrice: j['unitPrice'],
      options: opts.map((o) => o['name'] as String).toList(),
      productId: j['productId'],
      optionIds: opts.map((o) => o['id'] as String).toList(),
      note: j['note'],
    );
  }
}

/// Voucher aktif dari server (GET /vouchers/active).
class VoucherView {
  VoucherView({required this.code, required this.type, required this.value, required this.minSpend, this.maxDiscount, required this.endsAt, this.remaining});
  final String code, type;
  final int value, minSpend;
  final int? maxDiscount, remaining;
  final DateTime endsAt;

  String get headline => type == 'PERCENT' ? 'Diskon $value%' : 'Potongan Rp${_idr(value)}';

  String get detail {
    final parts = <String>[
      if (minSpend > 0) 'Min. belanja Rp${_idr(minSpend)}',
      if (type == 'PERCENT' && maxDiscount != null) 'maks Rp${_idr(maxDiscount!)}',
    ];
    return parts.isEmpty ? 'Tanpa minimum belanja' : parts.join(' • ');
  }

  static String _idr(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');

  factory VoucherView.fromJson(Map<String, dynamic> j) => VoucherView(
        code: j['code'],
        type: j['type'],
        value: j['value'],
        minSpend: j['minSpend'] ?? 0,
        maxDiscount: j['maxDiscount'],
        endsAt: DateTime.parse(j['endsAt']).toLocal(),
        remaining: j['remaining'],
      );
}

class OrderEventView {
  OrderEventView({required this.status, required this.at});
  final String status;
  final DateTime at;

  factory OrderEventView.fromJson(Map<String, dynamic> j) =>
      OrderEventView(status: j['status'], at: DateTime.parse(j['createdAt']).toLocal());
}

class OrderView {
  OrderView({
    required this.id,
    required this.code,
    required this.type,
    required this.status,
    required this.total,
    required this.subtotal,
    required this.discount,
    required this.deliveryFee,
    required this.pointsUsed,
    this.memberDiscount = 0,
    this.tierName,
    required this.createdAt,
    required this.items,
    this.outletName,
    this.payment,
    this.courierName,
    this.courierPhone,
    this.events = const [],
  });
  final String id, code, type, status;
  final int total, subtotal, discount, deliveryFee, pointsUsed, memberDiscount;
  final String? tierName;
  final DateTime createdAt;
  final List<OrderItemView> items;
  final String? outletName, courierName, courierPhone;
  final PaymentView? payment;
  final List<OrderEventView> events;

  bool get awaitingPayment => status == 'PENDING_PAYMENT';

  factory OrderView.fromJson(Map<String, dynamic> j) => OrderView(
        id: j['id'],
        code: j['code'],
        type: j['type'],
        status: j['status'],
        total: j['total'],
        subtotal: j['subtotal'],
        discount: j['discount'],
        deliveryFee: j['deliveryFee'],
        pointsUsed: j['pointsUsed'] ?? 0,
        memberDiscount: j['memberDiscount'] ?? 0,
        tierName: j['tierName'],
        createdAt: DateTime.parse(j['createdAt']).toLocal(),
        items: ((j['items'] as List?) ?? []).map((i) => OrderItemView.fromJson(i)).toList(),
        outletName: (j['outlet'] as Map?)?['name'],
        payment: j['payment'] is Map ? PaymentView.fromJson(Map<String, dynamic>.from(j['payment'] as Map), orderId: j['id']) : null,
        courierName: (j['courier'] as Map?)?['name'],
        courierPhone: (j['courier'] as Map?)?['phone'],
        events: ((j['events'] as List?) ?? []).map((e) => OrderEventView.fromJson(e)).toList(),
      );
}

/// Label status pesanan untuk pelanggan.
String statusLabel(String status, String type) => switch (status) {
      'PENDING_PAYMENT' => 'Menunggu pembayaran',
      'PAID' => 'Pesanan diterima',
      'PREPARING' => 'Sedang dibuat',
      'READY' => type == 'PICKUP' ? 'Siap diambil' : 'Siap dikirim',
      'ON_DELIVERY' => 'Dalam pengiriman',
      'COMPLETED' => 'Selesai',
      'CANCELLED' => 'Dibatalkan',
      'EXPIRED' => 'Kedaluwarsa',
      _ => status,
    };

/// Slide welcome/promo dari server (GET /promos/welcome), diatur admin di panel.
class PromoSlide {
  PromoSlide({required this.title, required this.body, this.imageUrl, this.art, this.ctaLabel, this.voucherCode});
  final String title, body;
  final String? imageUrl, art, ctaLabel, voucherCode;

  factory PromoSlide.fromJson(Map<String, dynamic> j) => PromoSlide(
        title: j['title'],
        body: j['body'],
        imageUrl: j['imageUrl'],
        art: j['art'],
        ctaLabel: j['ctaLabel'],
        voucherCode: j['voucherCode'],
      );
}

/// Metode bayar yang diaktifkan server (GET /payments/methods).
class PayMethod {
  PayMethod({required this.key, required this.label, required this.group});
  final String key, label, group; // group: qris | ewallet | va

  factory PayMethod.fromJson(Map<String, dynamic> j) => PayMethod(key: j['key'], label: j['label'], group: j['group']);
}

/// Tagihan aktif sebuah pesanan: isi QR, tautan aplikasi, atau nomor VA, plus batas waktu.
class PaymentView {
  PaymentView({
    required this.orderId,
    required this.method,
    required this.group,
    required this.status,
    required this.amount,
    this.expiresAt,
    this.qrString,
    this.qrImageUrl,
    this.ovoPhone,
    this.deeplinkUrl,
    this.vaBank,
    this.vaNumber,
    this.billerCode,
    this.billKey,
  });
  final String orderId, method, group, status;
  final int amount;
  final DateTime? expiresAt;
  final String? qrString, qrImageUrl, ovoPhone, deeplinkUrl, vaBank, vaNumber, billerCode, billKey;

  bool get isPending => status == 'PENDING';

  static String groupOf(String method) => method == 'qris'
      ? 'qris'
      : method.endsWith('_va')
          ? 'va'
          : 'ewallet';

  factory PaymentView.fromJson(Map<String, dynamic> j, {String orderId = ''}) {
    final method = (j['method'] ?? '') as String;
    final va = j['va'] as Map?;
    final bill = j['bill'] as Map?;
    return PaymentView(
      orderId: (j['orderId'] ?? orderId) as String,
      method: method,
      group: (j['group'] ?? groupOf(method)) as String,
      status: (j['status'] ?? 'PENDING') as String,
      amount: (j['amount'] ?? 0) as int,
      expiresAt: j['expiresAt'] == null ? null : DateTime.parse(j['expiresAt']).toLocal(),
      qrString: j['qrString'],
      qrImageUrl: j['qrImageUrl'],
      ovoPhone: (j['ovo'] as Map?)?['phone'],
      deeplinkUrl: j['deeplinkUrl'],
      vaBank: va?['bank'],
      vaNumber: va?['number'],
      billerCode: bill?['billerCode'],
      billKey: bill?['billKey'],
    );
  }
}

/// Satu baris riwayat poin (GET /me/points).
class PointEntry {
  PointEntry({required this.delta, required this.reason, required this.at});
  final int delta;
  final String reason;
  final DateTime at;

  String get label => switch (reason) {
        'ORDER' => 'Poin dari belanja',
        'REDEEM' => 'Tukar poin di checkout',
        'REFUND_REDEEM' => 'Poin dikembalikan',
        'REVOKE_EARNED' => 'Poin dibatalkan (pesanan dibatalkan)',
        _ => reason,
      };

  factory PointEntry.fromJson(Map<String, dynamic> j) =>
      PointEntry(delta: j['delta'], reason: j['reason'], at: DateTime.parse(j['createdAt']).toLocal());
}

/// Satu level keanggotaan (diatur admin di panel, mis. Member / Silver / Gold / Platinum).
class Tier {
  Tier({required this.id, required this.name, required this.minSpend, required this.earnMultiplierPct, required this.discountPct, this.maxDiscount});
  final String id, name;
  final int minSpend, earnMultiplierPct, discountPct;
  final int? maxDiscount;

  /// 125 -> "1,25×", 150 -> "1,5×", 200 -> "2×"
  String get multiplierLabel {
    final v = earnMultiplierPct / 100;
    final t = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString().replaceAll(RegExp(r'0+$'), '').replaceAll('.', ',');
    return '$t×';
  }

  bool get hasDiscount => discountPct > 0;

  factory Tier.fromJson(Map<String, dynamic> j) => Tier(
        id: j['id'],
        name: j['name'],
        minSpend: j['minSpend'],
        earnMultiplierPct: j['earnMultiplierPct'],
        discountPct: j['discountPct'],
        maxDiscount: j['maxDiscount'],
      );
}

/// Status keanggotaan pengguna (GET /me/membership).
class Membership {
  Membership({required this.lifetimeSpend, required this.current, this.next, this.remainingToNext, required this.progressPct, required this.tiers});
  final int lifetimeSpend;
  final Tier current;
  final Tier? next;
  final int? remainingToNext;
  final double progressPct; // 0-100
  final List<Tier> tiers;

  /// Indeks level pengguna di daftar (untuk memilih warna tampilan).
  int get currentIndex => tiers.indexWhere((t) => t.id == current.id).clamp(0, 99);

  factory Membership.fromJson(Map<String, dynamic> j) => Membership(
        lifetimeSpend: j['lifetimeSpend'],
        current: Tier.fromJson(j['current']),
        next: j['next'] == null ? null : Tier.fromJson(j['next']),
        remainingToNext: j['remainingToNext'],
        progressPct: (j['progressPct'] as num).toDouble(),
        tiers: (j['tiers'] as List).map((t) => Tier.fromJson(t)).toList(),
      );
}

/// Hadiah satu hari pada Daily Check-In.
class CheckInDay {
  CheckInDay({required this.day, required this.points, required this.claimed});
  final int day, points;
  final bool claimed;

  factory CheckInDay.fromJson(Map<String, dynamic> j) => CheckInDay(day: j['day'], points: j['points'], claimed: j['claimed']);
}

class CheckInView {
  CheckInView({required this.today, required this.claimedToday, required this.streak, required this.dayInCycle, required this.nextPoints, required this.rewards, this.awarded});
  final String today;
  final bool claimedToday;
  final int streak, dayInCycle, nextPoints;
  final List<CheckInDay> rewards;
  final int? awarded; // hanya ada pada respons POST

  factory CheckInView.fromJson(Map<String, dynamic> j) => CheckInView(
        today: j['today'],
        claimedToday: j['claimedToday'],
        streak: j['streak'],
        dayInCycle: j['dayInCycle'],
        nextPoints: j['nextPoints'],
        rewards: (j['rewards'] as List).map((r) => CheckInDay.fromJson(r)).toList(),
        awarded: j['awarded'],
      );
}

/// Satu item Kotak Masuk.
class InboxItem {
  InboxItem({required this.id, required this.type, required this.title, required this.body, this.orderId, required this.read, required this.createdAt});
  final String id, type, title, body;
  final String? orderId;
  final bool read;
  final DateTime createdAt;

  factory InboxItem.fromJson(Map<String, dynamic> j) => InboxItem(
        id: j['id'],
        type: j['type'],
        title: j['title'],
        body: j['body'],
        orderId: j['orderId'],
        read: j['read'],
        createdAt: DateTime.parse(j['createdAt']).toLocal(),
      );
}

class Inbox {
  Inbox({required this.unread, required this.items});
  final int unread;
  final List<InboxItem> items;

  factory Inbox.fromJson(Map<String, dynamic> j) => Inbox(unread: j['unread'], items: (j['items'] as List).map((i) => InboxItem.fromJson(i)).toList());
}
