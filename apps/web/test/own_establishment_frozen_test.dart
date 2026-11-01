// D-PV32 (Valdo 2026-10-20 — Infra-IA/prompts/prompt_privilegios_interfaces.md):
// o próprio estabelecimento pode ser papel; a cadeia e a aba Tributação ficam
// somente leitura — o app congela só essas abas (as do papel seguem vivas) e
// mostra a frase; a regra é da API (409 OWN_ESTABLISHMENT_READ_ONLY).

import 'dart:convert';
import 'dart:io';

// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setes_web/app/modules/customers/domain/entity/object_customer.dart';
import 'package:setes_web/app/shared/entity/widgets/own_establishment_frozen.dart';

void main() {
  setUpAll(() {
    final json = jsonDecode(File('assets/translations/pt.json').readAsStringSync()) as Map<String, dynamic>;
    Localization.load(const Locale('pt'), translations: Translations(json));
  });

  testWidgets('congelado: a frase aparece e o toque não chega ao filho; livre: o filho responde', (tester) async {
    var taps = 0;
    Widget child() => ElevatedButton(onPressed: () => taps++, child: const Text('campo'));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: OwnEstablishmentFrozen(frozen: true, child: child()))));
    expect(find.textContaining('próprio estabelecimento'), findsOneWidget);
    await tester.tap(find.text('campo'), warnIfMissed: false);
    await tester.pump();
    expect(taps, 0);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: OwnEstablishmentFrozen(frozen: false, child: child()))));
    expect(find.textContaining('próprio estabelecimento'), findsNothing);
    await tester.tap(find.text('campo'));
    await tester.pump();
    expect(taps, 1);
  });

  test('freezeChainTabs congela só os índices da cadeia/tributação — a aba do papel fica fora', () {
    final tabs = [const Text('main'), const Text('addr'), const Text('role'), const Text('tax')];
    final out = freezeChainTabs(tabs: tabs, frozen: true, indexes: const {0, 1, 3});
    expect(out.map((w) => w is OwnEstablishmentFrozen).toList(), [true, true, false, true]);
    expect(freezeChainTabs(tabs: tabs, frozen: false, indexes: const {0}).first, isA<OwnEstablishmentFrozen>());
  });

  test('o fato vem do GET (ownEstablishment) e sobrevive ao copyWith/mergeFiscal; nunca vai no body', () {
    final c = ObjectCustomer.fromJson({
      'id': 2, 'entity': <String, dynamic>{'nameCompany': 'Setes', 'nickTrade': 'Setes'}, 'personType': 'J', 'wallet': 'N', 'active': 'S',
      'ownEstablishment': true,
    });
    expect(c.ownEstablishment, isTrue);
    expect(c.copyWith(creditStatus: 'L').ownEstablishment, isTrue);
    expect(c.toJson().containsKey('ownEstablishment'), isFalse);
    final other = ObjectCustomer.fromJson({'id': 5, 'entity': <String, dynamic>{}, 'personType': 'J', 'wallet': 'N', 'active': 'S'});
    expect(other.ownEstablishment, isFalse);
  });
}
