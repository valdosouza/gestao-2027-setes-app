// D-PV2 (Valdo 2026-10-18 — Infra-IA/prompts/prompt_privilegios_interfaces.md):
// a fábrica de cadastros consulta o CRUD da tela atual num ponto só
// (CrudPrivileges sobre CurrentInterface). "Novo" ← INSERIR; salvar ← INSERIR
// (registro novo) ou ALTERAR (edição); excluir ← EXCLUIR. Sem interface
// conhecida (deep link) libera — quem decide de verdade é a API.

import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setes_web/app/shared/register/register_form_page.dart';
import 'package:setes_web/app/shared/register/register_form_shell.dart';
import 'package:setes_web/app/shared/register/register_search_page.dart';
import 'package:setes_web/app/shared/session/crud_privileges.dart';
import 'package:setes_web/app/shared/session/current_interface.dart';

MenuInterface _iface(List<String> privileges) =>
    MenuInterface(id: 9, description: 'Clientes', i18nKey: 'customers', privileges: privileges);

Widget _app(Widget child) => MaterialApp(home: child);

Future<void> _pumpShell(WidgetTester tester, {required bool creating}) =>
    tester.pumpWidget(_app(RegisterFormShell(
      title: 'Cliente',
      creating: creating,
      onBack: () {},
      onSave: () {},
      onDelete: () {},
      child: const SizedBox(),
    )));

Finder get _save => find.byIcon(Icons.check);
Finder get _delete => find.byIcon(Icons.delete_outline);

void main() {
  setUpAll(() {
    final json = jsonDecode(File('assets/translations/pt.json').readAsStringSync())
        as Map<String, dynamic>;
    Localization.load(const Locale('pt'), translations: Translations(json));
  });
  tearDown(() => CurrentInterface.value = null);

  group('CrudPrivileges (o ponto único)', () {
    test('lê os privilégios da interface atual — descrição do catálogo, sem diferenciar caixa', () {
      CurrentInterface.value = _iface(['VISUALIZAR', 'inserir']);
      expect([CrudPrivileges.canInsert, CrudPrivileges.canUpdate, CrudPrivileges.canDelete],
          [true, false, false]);
      expect(CrudPrivileges.canSave(creating: true), isTrue);
      expect(CrudPrivileges.canSave(creating: false), isFalse);
    });
    test('sem interface conhecida (deep link) libera — a API decide', () {
      CurrentInterface.value = null;
      expect([CrudPrivileges.canInsert, CrudPrivileges.canUpdate, CrudPrivileges.canDelete],
          [true, true, true]);
    });
  });

  group('RegisterFormShell (casca dos cadastros do cliente)', () {
    testWidgets('registro novo: o ✓ pede INSERIR; a lixeira nunca aparece', (tester) async {
      CurrentInterface.value = _iface(['VISUALIZAR', 'ALTERAR', 'EXCLUIR']);
      await _pumpShell(tester, creating: true);
      expect([_save, _delete].map((f) => f.evaluate().length), [0, 0]);
      CurrentInterface.value = _iface(['INSERIR']);
      await _pumpShell(tester, creating: true);
      expect([_save, _delete].map((f) => f.evaluate().length), [1, 0]);
    });
    testWidgets('edição: o ✓ pede ALTERAR e a lixeira, EXCLUIR — cada um por si', (tester) async {
      CurrentInterface.value = _iface(['VISUALIZAR', 'INSERIR']);
      await _pumpShell(tester, creating: false);
      expect([_save, _delete].map((f) => f.evaluate().length), [0, 0]);
      CurrentInterface.value = _iface(['ALTERAR']);
      await _pumpShell(tester, creating: false);
      expect([_save, _delete].map((f) => f.evaluate().length), [1, 0]);
      CurrentInterface.value = _iface(['EXCLUIR']);
      await _pumpShell(tester, creating: false);
      expect([_save, _delete].map((f) => f.evaluate().length), [0, 1]);
    });
    testWidgets('admin/super recebem o catálogo inteiro: tudo aparece', (tester) async {
      CurrentInterface.value = _iface(['VISUALIZAR', 'INSERIR', 'ALTERAR', 'EXCLUIR']);
      await _pumpShell(tester, creating: false);
      expect([_save, _delete].map((f) => f.evaluate().length), [1, 1]);
    });
  });

  group('RegisterSearchPage — "Novo" ← INSERIR', () {
    Future<void> pump(WidgetTester tester) => tester.pumpWidget(_app(RegisterSearchPage<int>(
          title: 'Clientes',
          items: const [1],
          rowBuilder: (i) => ['$i'],
          onFilterChanged: (_) {},
          onView: (_) {},
          onNew: () {},
        )));
    testWidgets('sem INSERIR o botão de novo some; com INSERIR aparece', (tester) async {
      CurrentInterface.value = _iface(['VISUALIZAR', 'ALTERAR', 'EXCLUIR']);
      await pump(tester);
      expect(find.byType(FloatingActionButton), findsNothing);
      CurrentInterface.value = _iface(['VISUALIZAR', 'INSERIR']);
      await pump(tester);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });

  group('RegisterFormPage — o privilégio soma à regra da página', () {
    Future<void> pump(WidgetTester tester, {required bool creating, bool canSave = true}) =>
        tester.pumpWidget(_app(RegisterFormPage(
          title: 'Vendedor',
          fields: const [],
          onSave: (_) {},
          onCancel: () {},
          onDelete: () {},
          canSave: canSave,
          canDelete: !creating,
          creating: creating,
        )));
    testWidgets('edição sem ALTERAR: sem ✓; com ALTERAR e regra da página falsa: sem ✓', (tester) async {
      CurrentInterface.value = _iface(['VISUALIZAR', 'INSERIR', 'EXCLUIR']);
      await pump(tester, creating: false);
      expect([_save, _delete].map((f) => f.evaluate().length), [0, 1]);
      CurrentInterface.value = _iface(['ALTERAR']);
      await pump(tester, creating: false, canSave: false);
      expect(_save, findsNothing);
      await pump(tester, creating: false);
      expect(_save, findsOneWidget);
    });
    testWidgets('registro novo: ✓ pede INSERIR', (tester) async {
      CurrentInterface.value = _iface(['ALTERAR', 'EXCLUIR']);
      await pump(tester, creating: true);
      expect([_save, _delete].map((f) => f.evaluate().length), [0, 0]);
      CurrentInterface.value = _iface(['INSERIR']);
      await pump(tester, creating: true);
      expect(_save, findsOneWidget);
    });
  });
}
