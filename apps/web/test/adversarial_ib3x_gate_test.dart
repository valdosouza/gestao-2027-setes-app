// GATE ADVERSARIAL da IB-3 no app (D-IB75/D-IB76 — prompt_fase_ibs_cbs.md §13; skill testar-adversarial.md).
// Cada teste fixa um achado CONFIRMADO contra a promessa do próprio pacote: "o parse tolera ausência/lixo — nunca exceção" e
// "os valores do fisco são texto decimal exato; ausente nunca vira zero" (cabeçalho de ibscbs_ib3_test.dart e de ibscbs.dart).
// Os testes FALHAM até a correção (o gate não corrige código de produção).

import 'dart:convert';
import 'dart:io';

// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setes_web/app/modules/orders/domain/entity/order_entity.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_entity.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_fiscal_entity.dart';
import 'package:setes_web/app/shared/ibscbs/ibscbs.dart';

Map<String, dynamic> _load(String lang) =>
    jsonDecode(File('assets/translations/$lang.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  setUpAll(() {
    Localization.load(const Locale('pt'), translations: Translations(_load('pt')));
  });

  // ADV-IB3X-01 — valor do fisco que não é número finito (texto "Infinity"/"NaN", JSON 1e400 → double.infinity → "Infinity")
  // vira "R$ 0,00": `jsonDouble` aceita o literal e `toCents` devolve 0 para não-finito. Ausente/ilegível tem que ser travessão.
  group('ADV-IB3X-01 — valor ilegível nunca vira R\$ 0,00', () {
    for (final raw in ['Infinity', '-Infinity', 'NaN', '1e400']) {
      test('ibscbsMoney("$raw")', () {
        expect(ibscbsMoney(raw), isNot('R\$ 0,00'));
        expect(ibscbsMoney(raw), '—');
      });
    }

    test('JSON numérico fora da faixa do double (1e400 → Infinity) no bloco da nfse-api', () {
      final v = ServiceOrderFiscalView.fromJson(
          jsonDecode('{"state":"authorized","ibscbs":{"declared":{"cst":"000","classificationCode":"000001",'
              '"placeIndicatorCode":"100301","nbs":"115021000"},"values":{"totalInvoiceValue":1e400,'
              '"ibsTotalValue":"0.25","cbsValue":"2.25"}}}') as Map<String, dynamic>);
      expect(ibscbsMoney(v.ibscbs!.totalInvoiceValue), '—');
    });

    testWidgets('o cartão não mostra R\$ 0,00 para total ilegível', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: IbscbsCard(
        fiscal: IbscbsFiscal(cst: '000', classificationCode: '000001', placeIndicatorCode: '100301', nbs: '115021000',
            totalInvoiceValue: 'NaN', ibsTotalValue: '0.25', cbsValue: '2.25'),
      ))));
      expect(find.textContaining('R\$ 0,00'), findsNothing);
    });
  });

  // ADV-IB3X-02 — "texto decimal EXATO": o TSDec15V2 do XSD (e o DECIMAL(17,2) da 007 da nfse-api) admite 15 inteiros; o app passa por
  // double e `toStringAsPrecision(15)` — a partir de 16 algarismos significativos o valor mostrado é OUTRO (centavos trocados).
  group('ADV-IB3X-02 — valor do fisco exato em todo o domínio do TSDec15V2', () {
    const cases = {
      '12345678901234.56': 'R\$ 12.345.678.901.234,56',
      '999999999999999.99': 'R\$ 999.999.999.999.999,99',
      '100000000000000.01': 'R\$ 100.000.000.000.000,01',
    };
    cases.forEach((raw, expected) {
      test('ibscbsMoney("$raw")', () => expect(ibscbsMoney(raw), expected));
    });
  });

  // ADV-IB3X-03 — tipos trocados lançam TypeError (casts `as List`/`as String?`) em vez de virar null: na linha do lote, UMA linha
  // derruba o relatório do bloco inteiro (o datasource lança depois que a API já faturou); no detalhe, derruba a OS inteira.
  group('ADV-IB3X-03 — parse tolerante: tipo trocado = null/vazio, nunca exceção', () {
    test('resultado do faturamento com omitted não-lista', () {
      expect(() => IbscbsOutcome.fromJson({'declared': false, 'omitted': 'not-classified'}), returnsNormally);
    });

    test('prévia com omitted não-lista', () {
      expect(() => IbscbsPreview.fromJson({'declared': false, 'omitted': {'x': 1}}), returnsNormally);
    });

    test('congelada com código numérico', () {
      expect(() => IbscbsFrozen.fromJson({'classificationCode': 1, 'placeIndicatorCode': 100301, 'nbs': 115021000}),
          returnsNormally);
    });

    test('enviada (nfse-api) com CST numérico', () {
      expect(() => IbscbsFiscal.fromJson({'declared': {'cst': 0, 'classificationCode': '000001'}}), returnsNormally);
    });

    test('UMA linha hostil não derruba o relatório do lote (as outras linhas — já faturadas na API — continuam visíveis)', () {
      expect(
        () => BatchInvoiceReport.fromJson({
          'results': [
            {'orderId': 1, 'ok': true, 'invoiceNumber': '700', 'ibscbs': {'declared': true, 'omitted': []}},
            {'orderId': 2, 'ok': true, 'invoiceNumber': '701', 'ibscbs': {'declared': false, 'omitted': 'nbs-missing'}},
          ],
        }),
        returnsNormally,
      );
    });

    test('detalhe da OS faturada não cai pela declaração congelada', () {
      expect(
        () => ServiceOrderFull.fromJson({
          'id': 1, 'customerId': 2, 'status': 'F',
          'ibscbs': {'preview': null, 'frozen': {'classificationCode': 1, 'placeIndicatorCode': null, 'nbs': null}},
        }),
        returnsNormally,
      );
    });

    test('validate da venda não cai pela prévia', () {
      expect(
        () => OrderBillingValidation.fromJson({'orderId': 9, 'issues': [], 'ibscbs': {'declared': false, 'omitted': 'x'}}),
        returnsNormally,
      );
    });
  });
}
