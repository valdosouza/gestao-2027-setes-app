// D-PV48 (Valdo 2026-10-27 — Infra-IA/prompts/prompt_privilegios_interfaces.md): a senha se define UMA vez, na criação da credencial;
// depois só o titular troca, pela recuperação — o cadastro só mostra o campo na inclusão ou em conta SEM credencial (A-PV23).
// D-PV57…D-PV60 (Valdo 2026-10-31): marcar um verbo marca o VISUALIZAR da mesma tela; desmarcar o VISUALIZAR desmarca tudo e diz o que
// sai antes de salvar; a concessão antiga sem VISUALIZAR abre como está, com o aviso — o salvar a acerta (a API aplica a mesma regra).

import 'dart:convert';
import 'dart:io';

// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setes_web/app/modules/users/presentation/widget/user_privileges_section.dart';
import 'package:setes_web/app/shared/users/datasource/user_datasource.dart';
import 'package:setes_web/app/shared/users/entity/user_entity.dart';

class _FakeUsers implements UserDatasource {
  _FakeUsers(this.items);
  List<UserInterfacePrivileges> items;
  final saved = <List<int>>[];

  @override
  Future<List<UserInterfacePrivileges>> getPrivileges(int userId, {int? institutionId}) async => items;

  @override
  Future<void> setPrivileges(int userId, int interfaceId, List<int> privilegeIds, {int? institutionId}) async {
    saved.add(privilegeIds);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

UserInterfacePrivileges _iface({required Set<int> granted}) => UserInterfacePrivileges(
      interfaceId: 30,
      description: 'Pedidos',
      groupDefault: 'Comercial',
      privileges: [
        for (final (id, name) in const [(6, 'VISUALIZAR'), (2, 'ALTERAR'), (3, 'EXCLUIR')])
          UserPrivilegeGrant(privilegeId: id, description: name, granted: granted.contains(id)),
      ],
    );

bool _checked(WidgetTester tester, String label) {
  final box = tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, label));
  return box.value ?? false;
}

void main() {
  setUpAll(() {
    final json = jsonDecode(File('assets/translations/pt.json').readAsStringSync()) as Map<String, dynamic>;
    Localization.load(const Locale('pt'), translations: Translations(json));
  });

  test('D-PV48: o GET diz se a credencial existe (nunca o hash); o PUT sem senha não manda o campo', () {
    final withCred = UserEntity.fromJson({'id': 5, 'nameCompany': 'A', 'nickTrade': 'a', 'email': 'a@x.com', 'hasCredential': true});
    final noCred = UserEntity.fromJson({'id': 6, 'nameCompany': 'B', 'nickTrade': 'b', 'email': 'b@x.com', 'hasCredential': false});
    expect([withCred.hasCredential, noCred.hasCredential], [true, false]);
    expect(withCred.toJson().containsKey('password'), isFalse);
    expect(const UserEntity(nameCompany: 'C', nickTrade: 'c', email: 'c@x.com', password: 'segredo1').toJson()['password'], 'segredo1');
  });

  Future<_FakeUsers> openDialog(WidgetTester tester, Set<int> granted) async {
    final users = _FakeUsers([_iface(granted: granted)]);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: UserPrivilegesSection(userId: 9, datasource: users, isSuper: false)))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pedidos'));
    await tester.pumpAndSettle();
    return users;
  }

  testWidgets('D-PV58: marcar um verbo marca o VISUALIZAR junto', (tester) async {
    final users = await openDialog(tester, {});
    await tester.tap(find.widgetWithText(CheckboxListTile, 'EXCLUIR'));
    await tester.pump();
    expect([_checked(tester, 'VISUALIZAR'), _checked(tester, 'EXCLUIR')], [true, true]);
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(users.saved.single..sort(), [3, 6]);
  });

  testWidgets('D-PV59: desmarcar o VISUALIZAR tira a tela inteira e mostra o que sai antes de salvar', (tester) async {
    final users = await openDialog(tester, {6, 2, 3});
    await tester.tap(find.widgetWithText(CheckboxListTile, 'VISUALIZAR'));
    await tester.pump();
    expect([_checked(tester, 'VISUALIZAR'), _checked(tester, 'ALTERAR'), _checked(tester, 'EXCLUIR')], [false, false, false]);
    expect(find.textContaining('Saem também: ALTERAR, EXCLUIR'), findsOneWidget);
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(users.saved.single, isEmpty);
  });

  testWidgets('D-PV60: concessão antiga (verbo sem VISUALIZAR) abre como está, avisada; mexer acerta pela regra', (tester) async {
    final users = await openDialog(tester, {2});
    expect([_checked(tester, 'VISUALIZAR'), _checked(tester, 'ALTERAR')], [false, true]);
    expect(find.textContaining('Concessão antiga sem Visualizar'), findsOneWidget);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'EXCLUIR'));
    await tester.pump();
    expect(_checked(tester, 'VISUALIZAR'), isTrue);
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(users.saved.single..sort(), [2, 3, 6]);
  });
}
