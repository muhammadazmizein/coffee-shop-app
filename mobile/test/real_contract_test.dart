import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopi_app/models/models.dart';

/// Memeriksa model Flutter terhadap respons ASLI server (disimpan di /tmp oleh langkah pengujian manual).
/// Dilewati bila berkas tidak ada, jadi aman di CI.
dynamic load(String name) => jsonDecode(File('/tmp/real_$name.json').readAsStringSync());
final available = File('/tmp/real_membership.json').existsSync() && File('/tmp/real_checkin.json').existsSync();

void main() {
  test('membership', () {
    final m = Membership.fromJson(Map<String, dynamic>.from(load('membership')));
    expect(m.tiers.length, greaterThanOrEqualTo(2));
    expect(m.tiers.map((t) => t.id), contains(m.current.id));
    expect(m.progressPct, inInclusiveRange(0, 100));
  }, skip: !available);

  test('riwayat poin', () {
    final list = (load('points') as List).map((e) => PointEntry.fromJson(e)).toList();
    for (final e in list) {
      expect(e.label, isNotEmpty);
    }
  }, skip: !available);

  test('pesanan (termasuk payment, memberDiscount, tierName)', () {
    final list = (load('orders') as List).map((o) => OrderView.fromJson(Map<String, dynamic>.from(o))).toList();
    expect(list, isNotEmpty);
    for (final o in list) {
      expect(o.memberDiscount, greaterThanOrEqualTo(0));
    }
  }, skip: !available);

  test('metode bayar, voucher, promo, outlet', () {
    final methods = (load('methods') as List).map((m) => PayMethod.fromJson(m)).toList();
    expect(methods.map((m) => m.key), containsAll(['qris', 'gopay', 'bca_va']));
    (load('vouchers') as List).map((v) => VoucherView.fromJson(v)).toList();
    final promos = (load('promos') as List).map((p) => PromoSlide.fromJson(p)).toList();
    expect(promos, isNotEmpty);
    final outlets = (load('outlets') as List).map((o) => Outlet.fromJson(o)).toList();
    expect(outlets.every((o) => o.deliveryRadiusKm >= 0), isTrue);
  }, skip: !available);

  test('profil (/me) membaca kelengkapan dan jumlah belum dibaca', () {
    final u = UserProfile.fromJson(Map<String, dynamic>.from(load('me')));
    expect(u.completionPercent, inInclusiveRange(0, 100));
    expect(u.unread, greaterThanOrEqualTo(0));
    expect(u.missing.every(['name', 'email', 'birthDate', 'gender', 'address'].contains), isTrue);
  }, skip: !available);

  test('check-in: 7 hari hadiah dan hari berjalan', () {
    final c = CheckInView.fromJson(Map<String, dynamic>.from(load('checkin')));
    expect(c.rewards.length, 7);
    expect(c.dayInCycle, inInclusiveRange(1, 7));
    expect(c.nextPoints, greaterThanOrEqualTo(0));
    expect(c.rewards.map((r) => r.day), [1, 2, 3, 4, 5, 6, 7]);
  }, skip: !available);

  test('kotak masuk terbaca', () {
    final i = Inbox.fromJson(Map<String, dynamic>.from(load('notifications')));
    expect(i.unread, greaterThanOrEqualTo(0));
    for (final n in i.items) {
      expect(n.title, isNotEmpty);
    }
  }, skip: !available);

  test('menu: 32 produk dari server terbaca', () {
    final cats = (load('menu') as List).map((c) => Category.fromJson(c)).toList();
    expect(cats.fold<int>(0, (n, c) => n + c.products.length), greaterThanOrEqualTo(32));
  }, skip: !available);
}
