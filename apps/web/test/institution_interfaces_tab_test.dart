// D-PV11 (Valdo 2026-10-18 — Infra-IA/prompts/prompt_privilegios_interfaces.md):
// a aba de interfaces do estabelecimento virou peça COMPARTILHADA (aba do
// Super + tela "Interfaces dos clientes", delegável). Cada tela entrega a SUA
// fonte; sem ALTERAR a aba fica só leitura (a API confere o mesmo par).
// D-PV34 (2026-10-20): cada marca é UMA chamada (concede/revoga UM id); a aba
// reflete o estado que a API devolve — nunca manda a lista inteira.

import 'dart:convert';
import 'dart:io';

// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setes_web/app/shared/institution_interfaces/institution_interface_grant.dart';
import 'package:setes_web/app/shared/institution_interfaces/institution_interfaces_source.dart';
import 'package:setes_web/app/shared/institution_interfaces/institution_interfaces_tab.dart';
import 'package:setes_widgets/setes_widgets.dart';

class _FakeSource implements InstitutionInterfacesSource {
  _FakeSource({this.answerLinked});
  final marks = <(int institutionId, int interfaceId, bool linked)>[];

  /// O que a API devolve como estado DEPOIS da marca (null = o pedido).
  final bool? answerLinked;

  @override
  Future<List<InstitutionInterfaceGrant>> getInterfaces(int institutionId) async => const [
        InstitutionInterfaceGrant(id: 9, description: 'Clientes', groupDefault: 'Cadastros', granted: true),
        InstitutionInterfaceGrant(id: 29, description: 'Pedidos', groupDefault: 'Vendas'),
      ];

  @override
  Future<InstitutionInterfaceLink> setInterface(int institutionId, int interfaceId, bool linked) async {
    marks.add((institutionId, interfaceId, linked));
    final after = answerLinked ?? linked;
    return InstitutionInterfaceLink(interfaceId: interfaceId, linked: after, changed: after != !linked);
  }
}

Future<_FakeSource> _pump(WidgetTester tester, {required bool canChange, bool? answerLinked}) async {
  final source = _FakeSource(answerLinked: answerLinked);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: InstitutionInterfacesTab(institutionId: 7, datasource: source, canChange: canChange)),
  ));
  await tester.pumpAndSettle();
  return source;
}

List<List<Object>> _boxes(WidgetTester tester) =>
    tester.widgetList<SetesCheckbox>(find.byType(SetesCheckbox)).map((b) => <Object>[b.label, b.value, b.enabled]).toList();

void main() {
  setUpAll(() {
    final json = jsonDecode(File('assets/translations/pt.json').readAsStringSync()) as Map<String, dynamic>;
    Localization.load(const Locale('pt'), translations: Translations(json));
  });

  testWidgets('sem ALTERAR: as interfaces aparecem, mas nenhuma marca é alterável', (tester) async {
    await _pump(tester, canChange: false);
    expect(_boxes(tester), [
      ['Clientes', true, false],
      ['Pedidos', false, false],
    ]);
  });

  testWidgets('com ALTERAR: marcar grava UMA marca (D-PV34) — o id e o estado pedido, nunca a lista', (tester) async {
    final source = await _pump(tester, canChange: true);
    await tester.tap(find.text('Pedidos'));
    await tester.pumpAndSettle();
    expect(source.marks, [(7, 29, true)]);
    await tester.tap(find.text('Clientes'));
    await tester.pumpAndSettle();
    expect(source.marks, [(7, 29, true), (7, 9, false)]);
    expect(_boxes(tester), [
      ['Clientes', false, true],
      ['Pedidos', true, true],
    ]);
  });

  testWidgets('a aba reflete o estado que a API DEVOLVE (idempotência/marca concorrente): pedido true, resposta false → fica false', (tester) async {
    await _pump(tester, canChange: true, answerLinked: false);
    await tester.tap(find.text('Pedidos'));
    await tester.pumpAndSettle();
    expect(_boxes(tester).firstWhere((b) => b[0] == 'Pedidos')[1], false);
  });
}
