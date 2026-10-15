// GATE ADVERSARIAL do DELTA do retrabalho da IB-3 no app (2026-10-15, rodada "ib3y" — skill testar-adversarial.md).
// Alvo: `IbscbsPreview.atObligation` (D-IB89) e o cartão que só renderiza — o bloco chega MALFORMADO (API mais nova/antiga, proxy, bug):
// o parse tolera e o cartão nunca lança; o que a tela diz com lixo fica FIXADO aqui (conhecimento, não falha).

import 'dart:convert';
import 'dart:io';

// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_entity.dart';
import 'package:setes_web/app/shared/ibscbs/ibscbs.dart';

Map<String, dynamic> _load(String lang) =>
    jsonDecode(File('assets/translations/$lang.json').readAsStringSync()) as Map<String, dynamic>;

Map<String, dynamic> _preview(Object? atObligation, {Object? obligationStart = '2027-01-01', Object? competenceDate = '2026-12-20'}) => {
      'competenceDate': competenceDate,
      'obligationStart': obligationStart,
      'obligatory': false,
      'declared': false,
      'omitted': ['not-classified'],
      'refusal': null,
      'atObligation': atObligation,
    };

void main() {
  setUpAll(() {
    Localization.load(const Locale('pt'), translations: Translations(_load('pt')));
  });

  group('ADV-IB3Y-APP — atObligation malformado: parse tolerante, cartão nunca lança', () {
    final hostile = <String, Object?>{
      'string': 'x',
      'lista': [1, 2],
      'número': 42,
      'mapa vazio': <String, dynamic>{},
      'refusal string': {'declared': false, 'refusal': 'recusada'},
      'refusal sem message': {'declared': false, 'refusal': {'code': 'X'}},
      'refusal message numérica': {'declared': false, 'refusal': {'message': 123}},
      'omitted com nulos': {'declared': false, 'omitted': [null, 7, 'nbs-missing']},
      'declared string': {'declared': 'true'},
    };
    hostile.forEach((name, at) {
      testWidgets('atObligation = $name', (tester) async {
        final p = IbscbsPreview.fromJson(jsonDecode(jsonEncode(_preview(at))));
        expect(p, isNotNull);
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: IbscbsCard(preview: p))));
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('ibscbs-preview')), findsOneWidget);
      });
    });

    test('lista/string/número = sem veredito na obrigação (null) — nenhuma linha inventada', () {
      for (final at in ['x', [1], 42]) {
        expect(IbscbsPreview.fromJson(jsonDecode(jsonEncode(_preview(at))))!.atObligation, isNull);
      }
    });

    testWidgets('obligationStart/competenceDate fora da forma (número, nulo, barra) — o cartão não lança', (tester) async {
      for (final d in [123, null, '2027/01/01', '']) {
        final p = IbscbsPreview.fromJson(jsonDecode(jsonEncode(_preview({'declared': false, 'refusal': {'message': 'R'}},
            obligationStart: d, competenceDate: d))));
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: IbscbsCard(preview: p))));
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('ibscbs-at-obligation')), findsOneWidget);
      }
    });

    test('OS aberta com bloco ibscbs malformado (preview string, frozen lista, unavailable "true") não derruba o detalhe', () {
      final os = ServiceOrderFull.fromJson(jsonDecode(jsonEncode({
        'id': 1, 'number': 1, 'customerId': 1, 'customerName': 'C', 'status': 'A', 'dtRecord': '2026-12-01', 'items': [],
        'totalValue': 0, 'ibscbs': {'preview': 'x', 'frozen': [1], 'unavailable': 'true'},
      })) as Map<String, dynamic>);
      expect(os.ibscbs, isNotNull);
      expect(os.ibscbs!.preview, isNull);
      expect(os.ibscbs!.frozen, isNull);
      expect(os.ibscbs!.unavailable, isFalse);
    });
  });
}
