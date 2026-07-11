// Smoke test do contrato visual da fábrica de cadastros
// (skill criar-formulario-cadastro.md): AppBar com voltar/salvar/excluir.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setes_widgets/setes_widgets.dart';

void main() {
  testWidgets('SetesFormShell mostra voltar, titulo, salvar e excluir',
      (WidgetTester tester) async {
    var backed = false;
    var saved = false;
    var deleted = false;

    await tester.pumpWidget(MaterialApp(
      home: SetesFormShell(
        title: 'Editar — País',
        onBack: () => backed = true,
        onSave: () => saved = true,
        onDelete: () => deleted = true,
        child: const SizedBox(),
      ),
    ));

    expect(find.text('Editar — País'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_rounded));
    await tester.tap(find.byIcon(Icons.check));
    await tester.tap(find.byIcon(Icons.delete_outline));

    expect(backed, isTrue);
    expect(saved, isTrue);
    expect(deleted, isTrue);
  });

  testWidgets('SetesFormShell em novo registro nao mostra excluir',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SetesFormShell(
        title: 'Adicionar — País',
        onBack: () {},
        onSave: () {},
        child: const SizedBox(),
      ),
    ));

    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });
}
