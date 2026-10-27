import 'package:flutter_test/flutter_test.dart';
import 'package:kopi_app/models/models.dart';

Tier t(int pct, {int disc = 0, int? max}) => Tier(id: 'x', name: 'X', minSpend: 0, earnMultiplierPct: pct, discountPct: disc, maxDiscount: max);

void main() {
  test('label pengali poin', () {
    expect(t(100).multiplierLabel, '1×');
    expect(t(125).multiplierLabel, '1,25×');
    expect(t(150).multiplierLabel, '1,5×');
    expect(t(200).multiplierLabel, '2×');
  });

  test('hasDiscount', () {
    expect(t(100).hasDiscount, isFalse);
    expect(t(150, disc: 5, max: 15000).hasDiscount, isTrue);
  });

  test('Membership membaca level, progres, dan daftar level', () {
    final m = Membership.fromJson({
      'lifetimeSpend': 600000,
      'current': {'id': 'a', 'name': 'Silver', 'minSpend': 500000, 'earnMultiplierPct': 125, 'discountPct': 3, 'maxDiscount': 10000, 'sort': 1},
      'next': {'id': 'b', 'name': 'Gold', 'minSpend': 2000000, 'earnMultiplierPct': 150, 'discountPct': 5, 'maxDiscount': null, 'sort': 2},
      'remainingToNext': 1400000,
      'progressPct': 7,
      'tiers': [
        {'id': 'z', 'name': 'Member', 'minSpend': 0, 'earnMultiplierPct': 100, 'discountPct': 0, 'maxDiscount': null, 'sort': 0},
        {'id': 'a', 'name': 'Silver', 'minSpend': 500000, 'earnMultiplierPct': 125, 'discountPct': 3, 'maxDiscount': 10000, 'sort': 1},
        {'id': 'b', 'name': 'Gold', 'minSpend': 2000000, 'earnMultiplierPct': 150, 'discountPct': 5, 'maxDiscount': null, 'sort': 2},
      ],
    });
    expect(m.current.name, 'Silver');
    expect(m.currentIndex, 1);
    expect(m.next?.name, 'Gold');
    expect(m.remainingToNext, 1400000);
    expect(m.progressPct, 7.0);
    expect(m.tiers.length, 3);
    expect(m.tiers.last.maxDiscount, isNull);
  });

  test('Level tertinggi: tidak ada level berikutnya', () {
    final m = Membership.fromJson({
      'lifetimeSpend': 9000000,
      'current': {'id': 'p', 'name': 'Platinum', 'minSpend': 5000000, 'earnMultiplierPct': 200, 'discountPct': 8, 'maxDiscount': 25000, 'sort': 3},
      'next': null, 'remainingToNext': null, 'progressPct': 100,
      'tiers': [{'id': 'p', 'name': 'Platinum', 'minSpend': 5000000, 'earnMultiplierPct': 200, 'discountPct': 8, 'maxDiscount': 25000, 'sort': 3}],
    });
    expect(m.next, isNull);
    expect(m.remainingToNext, isNull);
  });

  test('OrderView membaca diskon member (dan aman untuk order lama tanpa field itu)', () {
    final base = {'id': 'x', 'code': 'K', 'type': 'PICKUP', 'status': 'PAID', 'total': 1000, 'subtotal': 1000, 'discount': 0, 'deliveryFee': 0, 'createdAt': '2026-10-23T05:00:00.000Z'};
    expect(OrderView.fromJson(base).memberDiscount, 0);
    final o = OrderView.fromJson({...base, 'memberDiscount': 1500, 'tierName': 'Gold'});
    expect(o.memberDiscount, 1500);
    expect(o.tierName, 'Gold');
  });
}
