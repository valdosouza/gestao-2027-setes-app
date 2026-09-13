// Contrato de dados do LOTE da cobrança mensal (D6/D7 da fase Primeiro
// Cliente): a API responde 200 mesmo com falhas parciais, então o que a tela
// lê é o RELATÓRIO — e ele precisa sobreviver a DECIMAL vindo como string, a
// linha sem motivo e a relatório vazio.

import 'package:flutter_test/flutter_test.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_entity.dart';

void main() {
  group('BatchInvoiceReport.fromJson', () {
    test('lê contadores e uma linha por ordem, faturada e recusada', () {
      final report = BatchInvoiceReport.fromJson({
        'requested': 3,
        'invoiced': 2,
        'failed': 1,
        'results': [
          {'orderId': 10, 'ok': true, 'invoiceNumber': '6540', 'totalValue': '250.00'},
          {'orderId': 11, 'ok': false, 'error': 'Ordem já faturada', 'code': 'ORDER_INVOICED'},
          {'orderId': 12, 'ok': true, 'invoiceNumber': '6541', 'totalValue': 99.9},
        ],
      });

      expect(report.requested, 3);
      expect(report.invoiced, 2);
      expect(report.failed, 1);
      expect(report.results, hasLength(3));

      final faturada = report.results.first;
      expect(faturada.ok, isTrue);
      expect(faturada.invoiceNumber, '6540');
      expect(faturada.totalValue, 250.00); // DECIMAL como string do mysql2

      final recusada = report.results[1];
      expect(recusada.ok, isFalse);
      expect(recusada.error, 'Ordem já faturada');
      expect(recusada.code, 'ORDER_INVOICED');
      expect(recusada.invoiceNumber, isEmpty);
    });

    test('linha sem ok explícito NÃO é tratada como faturada', () {
      final report = BatchInvoiceReport.fromJson({
        'requested': 1, 'invoiced': 0, 'failed': 1,
        'results': [
          {'orderId': 10},
        ],
      });

      expect(report.results.single.ok, isFalse);
      expect(report.results.single.error, isEmpty);
    });

    test('envelope sem results devolve relatório vazio (nunca quebra a tela)', () {
      final report = BatchInvoiceReport.fromJson(const {});

      expect(report.requested, 0);
      expect(report.invoiced, 0);
      expect(report.failed, 0);
      expect(report.results, isEmpty);
    });
  });

  group('uncharged — "faturada" não quer dizer "cobrada"', () {
    test('lê o contador e o que a automação fez em cada linha', () {
      final report = BatchInvoiceReport.fromJson({
        'requested': 2, 'invoiced': 2, 'failed': 0, 'uncharged': 1,
        'results': [
          {'orderId': 10, 'ok': true, 'invoiceNumber': '1', 'autoSettled': 0, 'bankSlipsIssued': 1},
          {'orderId': 11, 'ok': true, 'invoiceNumber': '2', 'autoSettled': 0, 'bankSlipsIssued': 0},
        ],
      });

      expect(report.uncharged, 1);
      expect(report.results.first.bankSlipsIssued, 1);
      expect(report.results[1].bankSlipsIssued, 0);
      expect(report.results[1].autoSettled, 0);
    });

    test('envelope antigo sem uncharged não quebra a tela', () {
      final report = BatchInvoiceReport.fromJson({
        'requested': 1, 'invoiced': 1, 'failed': 0,
        'results': [{'orderId': 10, 'ok': true}],
      });

      expect(report.uncharged, 0);
      expect(report.results.single.bankSlipsIssued, 0);
    });
  });

  group('ServiceOrderInvoiceInput (condições do lote)', () {
    test('toJson leva as MESMAS condições que a rota de uma ordem só', () {
      const input = ServiceOrderInvoiceInput(
        dtExpiration: '2026-10-05', paymentTypeId: 6, parcels: 2);

      expect(input.toJson(), {
        'dtExpiration': '2026-10-05',
        'paymentTypeId': 6,
        'parcels': 2,
      });
    });

    // D13: no lote, a AUSÊNCIA do vencimento é que diz à API "use o dia do
    // contrato de cada ordem". Mandar string vazia faria a API recusar por
    // formato — o vazio não pode viajar.
    test('vencimento vazio NÃO viaja no payload (é a ausência que significa)', () {
      const input = ServiceOrderInvoiceInput(
        dtExpiration: '', paymentTypeId: 6, parcels: 1);

      expect(input.toJson().containsKey('dtExpiration'), isFalse);
      expect(input.toJson(), {'paymentTypeId': 6, 'parcels': 1});
    });

    // D14: mesma regra para a forma — 0 significa "a do contrato de cada ordem".
    test('forma 0 também não viaja (condições do contrato)', () {
      const input = ServiceOrderInvoiceInput(
        dtExpiration: '', paymentTypeId: 0, parcels: 1);

      expect(input.toJson(), {'parcels': 1});
    });
  });

  group('vencimento por ordem no relatório (D13)', () {
    test('cada linha traz o vencimento que a ordem REALMENTE recebeu', () {
      final report = BatchInvoiceReport.fromJson({
        'requested': 2, 'invoiced': 2, 'failed': 0, 'uncharged': 0,
        'results': [
          {'orderId': 10, 'ok': true, 'dtExpiration': '2026-10-10', 'invoiceNumber': '6700'},
          {'orderId': 11, 'ok': true, 'dtExpiration': '2026-10-25', 'invoiceNumber': '6701'},
        ],
      });

      expect(report.results.map((r) => r.dtExpiration),
          ['2026-10-10', '2026-10-25']);
    });

    test('ordem sem dia de contrato vem recusada com o código próprio', () {
      final report = BatchInvoiceReport.fromJson({
        'requested': 1, 'invoiced': 0, 'failed': 1, 'uncharged': 0,
        'results': [
          {
            'orderId': 12, 'ok': false,
            'code': 'ORDER_NO_CONTRACT_DUE_DAY',
            'error': 'Ordem sem dia de vencimento de contrato — informe o vencimento do lote ou acerte o contrato do cliente',
          },
        ],
      });

      expect(report.results.single.code, 'ORDER_NO_CONTRACT_DUE_DAY');
      expect(report.results.single.dtExpiration, isEmpty);
    });
  });
}
