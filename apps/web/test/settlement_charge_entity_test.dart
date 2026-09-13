// Contrato de dados da RENEGOCIAÇÃO no financeiro (D17/D18): o que a tela lê
// do PUT /api/settlements/bills/:orderId/:parcel/charge.

import 'package:flutter_test/flutter_test.dart';
import 'package:setes_web/app/modules/settlements/domain/entity/settlement_entity.dart';

void main() {
  group('SettlementChargeResult.fromJson', () {
    test('lê de onde veio e para onde foi — a tela mostra "de X para Y"', () {
      final r = SettlementChargeResult.fromJson({
        'orderId': 7983, 'parcel': 1,
        'previousPaymentTypeId': 1, 'paymentTypeId': 6,
        'dtExpiration': '2026-12-07', 'changed': true,
      });

      expect(r.orderId, 7983);
      expect(r.previousPaymentTypeId, 1);
      expect(r.paymentTypeId, 6);
      expect(r.changed, isTrue);
    });

    test('changed false: o operador escolheu a forma que já valia', () {
      final r = SettlementChargeResult.fromJson({
        'orderId': 1, 'parcel': 1, 'previousPaymentTypeId': 6,
        'paymentTypeId': 6, 'dtExpiration': '2026-12-07', 'changed': false,
      });

      expect(r.changed, isFalse);
      expect(r.previousPaymentTypeId, r.paymentTypeId);
    });

    test('envelope vazio não quebra a tela', () {
      final r = SettlementChargeResult.fromJson(const {});

      expect(r.orderId, 0);
      expect(r.changed, isFalse);
      expect(r.dtExpiration, isEmpty);
    });
  });

  group('SettlementPaymentTypeLookup', () {
    test('lê id e descrição do lookup de formas', () {
      final t = SettlementPaymentTypeLookup.fromJson(
          {'id': 6, 'description': '6 - BOLETO'});

      expect(t.id, 6);
      expect(t.description, '6 - BOLETO');
    });
  });
}
