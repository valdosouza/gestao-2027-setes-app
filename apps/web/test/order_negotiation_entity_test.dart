// Contrato de dados da NEGOCIAÇÃO do pedido (módulo orders): parse do
// GET /api/orders/:id/negotiation, derivações (modo, parcelas efetivas,
// parcela em cheque) e payloads do PUT e do bloco `checks` do invoice.

import 'package:flutter_test/flutter_test.dart';
import 'package:setes_web/app/modules/orders/domain/entity/order_entity.dart';

void main() {
  group('OrderNegotiation.fromJson', () {
    test('lê cabeçalho, base, grade elaborada e preview', () {
      final negotiation = OrderNegotiation.fromJson({
        'orderId': 41,
        'status': 'A',
        'mode': 'elaborated',
        'billing': {
          'paymentTypeId': 3,
          'paymentTypeDescription': 'Cheque',
          'paymentTypeKind': 'Q',
          'maxParcels': 3,
          'deadline': '028/056',
          'plots': 2,
        },
        'base': {'itemsValue': '90.00', 'freight': 10, 'base': '100.00'},
        'installments': [
          {
            'parcel': 1,
            'dueDate': '2026-10-04',
            'amount': '60.00',
            'paymentTypeId': 3,
            'paymentTypeDescription': 'Cheque',
            'paymentTypeKind': 'Q',
            'ownPaymentType': false,
          },
          {
            'parcel': 2,
            'dueDate': '2026-11-03',
            'amount': 40,
            'paymentTypeId': 5,
            'paymentTypeDescription': 'Boleto',
            'paymentTypeKind': 'B',
            'ownPaymentType': true,
          },
        ],
        'preview': [
          {'parcel': 1, 'dueDate': '2026-10-04', 'amount': 50, 'paymentTypeId': 3},
        ],
      });

      expect(negotiation.orderId, 41);
      expect(negotiation.isOpen, isTrue);
      expect(negotiation.isElaborated, isTrue);
      expect(negotiation.billing?.isCheck, isTrue);
      expect(negotiation.billing?.maxParcels, 3);
      expect(negotiation.base.base, 100);
      expect(negotiation.base.itemsValue, 90);
      expect(negotiation.installments, hasLength(2));
      expect(negotiation.installments.last.ownPaymentType, isTrue);
      expect(negotiation.installments.last.isCheck, isFalse);
      // Elaborada presente → o faturamento usa a grade, não o preview.
      expect(negotiation.effectiveParcels, negotiation.installments);
      expect(negotiation.hasCheckParcel, isTrue);
    });

    test('prazo (D-N4): legado do sync = deadlineValid false; válido fora do canônico avisa; ausente = válido',
        () {
      final legacy = OrderNegotiationBilling.fromJson({
        'paymentTypeId': 3,
        'deadline': 'A VISTA',
        'deadlineCanonical': null,
        'deadlineValid': false,
      });
      expect(legacy.isLegacyDeadline, isTrue);
      expect(legacy.deadlineNeedsCanonical, isFalse);

      final loose = OrderNegotiationBilling.fromJson({
        'paymentTypeId': 3,
        'deadline': '30/60',
        'deadlineCanonical': '030/060',
        'deadlineValid': true,
      });
      expect(loose.isLegacyDeadline, isFalse);
      expect(loose.deadlineNeedsCanonical, isTrue);

      // '0' gravado por SQL = à vista: canônico null NÃO avisa (null também
      // é "campo ausente" — a API regrava como NULL em silêncio).
      final zero = OrderNegotiationBilling.fromJson({
        'paymentTypeId': 3,
        'deadline': '0',
        'deadlineCanonical': null,
        'deadlineValid': true,
      });
      expect(zero.deadlineNeedsCanonical, isFalse);

      final canonical = OrderNegotiationBilling.fromJson({
        'paymentTypeId': 3,
        'deadline': '028/056',
        'deadlineCanonical': '028/056',
        'deadlineValid': true,
      });
      expect(canonical.deadlineNeedsCanonical, isFalse);
      // Resposta sem os campos (contrato antigo) = válido e canônico.
      final bare = OrderNegotiationBilling.fromJson({'paymentTypeId': 3});
      expect(bare.deadlineValid, isTrue);
      expect(bare.deadlineNeedsCanonical, isFalse);
    });

    test('via simples: parcelas efetivas = preview; sem billing = sem cheque',
        () {
      final simple = OrderNegotiation.fromJson({
        'orderId': 1,
        'status': 'F',
        'mode': 'simple',
        'billing': null,
        'base': {'itemsValue': 0, 'freight': 0, 'base': 0},
        'installments': [],
        'preview': [
          {'parcel': 1, 'dueDate': '2026-10-04', 'amount': 10, 'paymentTypeId': 2, 'paymentTypeKind': 'E'},
        ],
      });
      expect(simple.isOpen, isFalse);
      expect(simple.isElaborated, isFalse);
      expect(simple.billing, isNull);
      expect(simple.effectiveParcels, hasLength(1));
      expect(simple.hasCheckParcel, isFalse);
    });
  });

  group('OrderNegotiationInput.toJson', () {
    test('via simples: prazo vazio vira null e installments é OMITIDO', () {
      const input = OrderNegotiationInput(paymentTypeId: 3, deadline: '   ');
      expect(input.isElaborated, isFalse);
      expect(input.toJson(), {'paymentTypeId': 3, 'deadline': null});
    });

    test('via elaborada: linhas com forma null = herda (nunca o id do cabeçalho)',
        () {
      const input = OrderNegotiationInput(
        paymentTypeId: 3,
        deadline: '028/056',
        installments: [
          OrderInstallmentInput(parcel: 1, dueDate: '2026-10-04', amount: 60),
          OrderInstallmentInput(
              parcel: 2, dueDate: '2026-11-03', amount: 40, paymentTypeId: 5),
        ],
      );
      expect(input.isElaborated, isTrue);
      final json = input.toJson();
      expect(json['deadline'], '028/056');
      final rows = json['installments'] as List<dynamic>;
      expect(rows, hasLength(2));
      expect((rows.first as Map)['paymentTypeId'], isNull);
      expect((rows.last as Map)['paymentTypeId'], 5);
    });

    test('lista vazia NÃO é elaborada (equivale a voltar ao prazo)', () {
      const input =
          OrderNegotiationInput(paymentTypeId: 3, installments: []);
      expect(input.isElaborated, isFalse);
      expect(input.toJson().containsKey('installments'), isFalse);
    });
  });

  test('OrderParcelChecksInput monta o bloco checks do invoice e soma', () {
    const parcel = OrderParcelChecksInput(parcel: 1, items: [
      OrderCheckInput(
        bankId: 1,
        bankLabel: '001 - Banco do Brasil',
        agency: '1234',
        account: '56789-0',
        number: '000101',
        issuer: 'Fulano',
        value: 60.5,
        dtCheck: '2026-10-04',
      ),
      OrderCheckInput(
        bankId: 2,
        agency: '1',
        account: '2',
        number: '3',
        issuer: 'Beltrano',
        value: 39.5,
        dtCheck: '2026-10-04',
        kind: OrderCheckKind.third,
      ),
    ]);
    expect(parcel.sum, 100);
    final json = parcel.toJson();
    expect(json['parcel'], 1);
    final items = json['items'] as List<dynamic>;
    expect(items, hasLength(2));
    // bankLabel é só exibição local — nunca viaja para a API.
    expect((items.first as Map).containsKey('bankLabel'), isFalse);
    expect((items.first as Map)['kind'], 'P');
    expect((items.last as Map)['kind'], 'T');
  });

  test('OrderBankLookup.display concatena número e descrição', () {
    expect(
        const OrderBankLookup(id: 1, number: '001', description: 'Banco do Brasil')
            .display,
        '001 - Banco do Brasil');
    expect(const OrderBankLookup(id: 2, number: '999').display, '999');
  });
}
