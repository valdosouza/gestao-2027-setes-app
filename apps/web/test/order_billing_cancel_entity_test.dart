// Contrato de dados do CANCELAMENTO da nota (POST /api/billing/cancel —
// prompt_cancelamento_nota.md Onda 1): parse do envelope de sucesso.

import 'package:flutter_test/flutter_test.dart';
import 'package:setes_web/app/modules/orders/domain/entity/order_entity.dart';

void main() {
  group('OrderBillingCancel.fromJson', () {
    test('lê número, evento C e o que foi desfeito junto', () {
      final r = OrderBillingCancel.fromJson({
        'orderId': 6635,
        'invoiceNumber': '6192',
        'event': 2,
        'checksReversed': [44, 45],
        'bankSlipsCancelled': [10],
        'commissionsCompensated': 3,
      });
      expect(r.orderId, 6635);
      expect(r.invoiceNumber, '6192');
      expect(r.event, 2);
      expect(r.checksReversed, 2);
      expect(r.bankSlipsCancelled, 1);
      expect(r.commissionsCompensated, 3);
    });

    test('envelope mínimo não quebra', () {
      final r = OrderBillingCancel.fromJson(const {'orderId': 1});
      expect(r.invoiceNumber, '');
      expect(r.event, 0);
      expect(r.checksReversed, 0);
      expect(r.bankSlipsCancelled, 0);
      expect(r.commissionsCompensated, 0);
    });
  });
}
