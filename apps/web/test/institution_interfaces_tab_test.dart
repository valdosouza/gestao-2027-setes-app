// D-PV11 (Valdo 2026-10-18 — Infra-IA/prompts/prompt_privilegios_interfaces.md):
// a aba de interfaces do estabelecimento virou peça COMPARTILHADA (aba do
// Super + tela "Interfaces dos clientes", delegável). Cada tela entrega a SUA
// fonte; sem ALTERAR a aba fica só leitura (a API confere o mesmo par).

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
  final saved = <List<int>>[];

  @override
  Future<List<InstitutionInterfaceGrant>> getInterfaces(int institutionId) async => const [
        InstitutionInterfaceGrant(id: 9, description: 'Clientes', groupDefault: 'Cadastros', granted: true),
        InstitutionInterfaceGrant(id: 29, description: 'Pedidos', groupDefault: 'Vendas'),
      ];

  @override
  Future<void> setInterfaces(int institutionId, List<int> interfaceIds) async => saved.add(interfaceIds);
}

Future<_FakeSource> _pump(WidgetTester tester, {required bool canChange}) async {
  final source = _FakeSource();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: InstitutionInterfacesTab(institutionId: 7, datasource: source, canChange: canChange)),
  ));
  await tester.pumpAndSettle();
  return source;
}

void main() {
  setUpAll(() {
    final json = jsonDecode(File('assets/translations/pt.json').readAsStringSync()) as Map<String, dynamic>;
    Localization.load(const Locale('pt'), translations: Translations(json));
  });

  testWidgets('sem ALTERAR: as interfaces aparecem, mas nenhuma marca é alterável', (tester) async {
    await _pump(tester, canChange: false);
    final boxes = tester.widgetList<SetesCheckbox>(find.byType(SetesCheckbox)).toList();
    expect(boxes.map((b) => [b.label, b.value, b.enabled]).toList(), [
      ['Clientes', true, false],
      ['Pedidos', false, false],
    ]);
  });

  testWidgets('com ALTERAR: marcar grava a lista COMPLETA pela fonte da tela', (tester) async {
    final source = await _pump(tester, canChange: true);
    await tester.tap(find.text('Pedidos'));
    await tester.pumpAndSettle();
    expect(source.saved, [
      [9, 29],
    ]);
  });
}
