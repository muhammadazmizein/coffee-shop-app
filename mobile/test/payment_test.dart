import 'package:flutter_test/flutter_test.dart';
import 'package:kopi_app/models/models.dart';
import 'package:kopi_app/screens/pay_screen.dart';

void main() {
  test('mmss: hitung mundur tidak pernah negatif', () {
    expect(mmss(const Duration(seconds: 125)), '02:05');
    expect(mmss(const Duration(minutes: 29, seconds: 59)), '29:59');
    expect(mmss(const Duration(seconds: -5)), '00:00');
  });

  group('PaymentView', () {
    test('VA bank', () {
      final p = PaymentView.fromJson({
        'orderId': 'o1', 'method': 'bca_va', 'status': 'PENDING', 'amount': 46800,
        'expiresAt': '2026-10-23T08:00:00.000Z', 'va': {'bank': 'bca', 'number': '12345678901'},
      });
      expect(p.group, 'va');
      expect(p.vaNumber, '12345678901');
      expect(p.vaBank, 'bca');
      expect(p.isPending, isTrue);
      expect(p.expiresAt, isNotNull);
    });

    test('Mandiri memakai kode perusahaan dan kode bayar', () {
      final p = PaymentView.fromJson({'method': 'mandiri_va', 'amount': 1000, 'bill': {'billerCode': '70012', 'billKey': '998877'}}, orderId: 'o2');
      expect(p.orderId, 'o2');
      expect(p.billerCode, '70012');
      expect(p.billKey, '998877');
      expect(p.vaNumber, isNull);
    });

    test('QRIS dan GoPay membawa isi QR, group diturunkan dari metode', () {
      final q = PaymentView.fromJson({'method': 'qris', 'amount': 5000, 'qrString': '000201...'});
      expect(q.group, 'qris');
      expect(q.qrString, isNotNull);
      final g = PaymentView.fromJson({'method': 'gopay', 'amount': 5000, 'qrString': 'x', 'deeplinkUrl': 'gojek://gopay/merchanttransfer?x=1'});
      expect(g.group, 'ewallet');
      expect(g.deeplinkUrl, startsWith('gojek://'));
    });

    test('GoPay: QR berupa gambar; OVO membawa nomor', () {
      final g = PaymentView.fromJson({'method': 'gopay', 'amount': 1, 'qrImageUrl': 'https://x/qr.png', 'deeplinkUrl': 'https://sim'});
      expect(g.qrString, isNull);
      expect(g.qrImageUrl, 'https://x/qr.png');
      final o = PaymentView.fromJson({'method': 'ovo', 'amount': 1, 'ovo': {'phone': '6281299990001'}});
      expect(o.ovoPhone, '6281299990001');
      expect(o.group, 'ewallet');
    });

    test('status tidak PENDING berarti tagihan tidak aktif', () {
      expect(PaymentView.fromJson({'method': 'qris', 'status': 'EXPIRED', 'amount': 1}).isPending, isFalse);
    });
  });

  test('OrderView membaca payment bila ada, null bila tidak', () {
    final base = {'id': 'x', 'code': 'KP1', 'type': 'PICKUP', 'status': 'PENDING_PAYMENT', 'total': 1000, 'subtotal': 1000, 'discount': 0, 'deliveryFee': 0, 'createdAt': '2026-10-23T05:00:00.000Z'};
    expect(OrderView.fromJson(base).payment, isNull);
    final withPay = OrderView.fromJson({...base, 'payment': {'method': 'qris', 'status': 'PENDING', 'amount': 1000, 'qrString': 'abc'}});
    expect(withPay.payment?.orderId, 'x');
    expect(withPay.awaitingPayment, isTrue);
  });
}
