// Contrato de dados do módulo bank_slips (Boletos): parse do detalhe
// (/api/bank-slips/:id), estado derivado e payload da emissão.

import 'package:flutter_test/flutter_test.dart';
import 'package:setes_web/app/modules/bank_slips/domain/entity/bank_slip_entity.dart';

void main() {
  group('BankSlipFull.fromJson', () {
    test('lê cabeçalho, taxas congeladas, títulos e eventos', () {
      final slip = BankSlipFull.fromJson({
        'id': 7,
        'ourNumber': '000123',
        'documentNumber': '12-1',
        'dtEmission': '2026-09-04',
        'dtExpiration': '2026-09-30',
        'value': '150.50', // mysql2 pode devolver DECIMAL como string
        'state': 'settled',
        'bankAccountLabel': '341 - Itaú',
        'customerName': 'Cliente X',
        'titles': 2,
        'agreementId': 3,
        'bankAccountId': 9,
        'aliqInterest': 1.5,
        'protestDays': 5,
        'titleRows': [
          {'orderId': 12, 'parcel': 1, 'value': 100, 'entityName': 'Cliente X'},
          {'orderId': 12, 'parcel': 2, 'value': 50.5},
        ],
        'events': [
          {'event': 1, 'kind': 'E', 'dtRecord': '2026-09-04', 'source': 'M'},
          {'event': 2, 'kind': 'L', 'settledCode': 55, 'paidValue': 150.5},
        ],
      });

      expect(slip.id, 7);
      expect(slip.value, 150.5);
      expect(slip.isSettled, isTrue);
      expect(slip.isOpen, isFalse);
      expect(slip.aliqInterest, 1.5);
      expect(slip.aliqFine, isNull);
      expect(slip.titleRows, hasLength(2));
      expect(slip.titleRows.last.value, 50.5);
      expect(slip.events.last.kind, BankSlipEventKind.settled);
      expect(slip.events.last.settledCode, 55);
    });

    test('estado ausente = aberto', () {
      final row = BankSlipListRow.fromJson({'id': 1});
      expect(row.state, BankSlipStatus.open);
      expect(row.isOpen, isTrue);
    });
  });

  test('BankSlipIssueInput.toJson monta o payload do POST', () {
    const input = BankSlipIssueInput(
      agreementId: 3,
      titles: [
        BankSlipTitleRef(orderId: 12, parcel: 1),
        BankSlipTitleRef(orderId: 12, parcel: 2),
      ],
      dtExpiration: '2026-10-10',
    );
    expect(input.toJson(), {
      'agreementId': 3,
      'titles': [
        {'orderId': 12, 'parcel': 1},
        {'orderId': 12, 'parcel': 2},
      ],
      'dtExpiration': '2026-10-10',
    });
  });

  test('BankSlipOpenTitle.key identifica a parcela na seleção', () {
    final title = BankSlipOpenTitle.fromJson(
        {'orderId': 12, 'parcel': 3, 'balance': '10.00', 'customerId': 4});
    expect(title.key, '12-3');
    expect(title.balance, 10);
    expect(title.ref, const BankSlipTitleRef(orderId: 12, parcel: 3));
  });
}
