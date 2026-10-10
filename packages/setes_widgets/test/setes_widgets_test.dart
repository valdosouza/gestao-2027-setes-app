import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setes_widgets/setes_widgets.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('SetesText renderiza o texto', (tester) async {
    await tester.pumpWidget(wrap(const SetesText('Olá Setes')));
    expect(find.text('Olá Setes'), findsOneWidget);
  });

  testWidgets('SetesButton desabilita e mostra progresso quando loading', (tester) async {
    var pressed = false;
    await tester.pumpWidget(wrap(SetesButton(
      label: 'Salvar',
      loading: true,
      onPressed: () => pressed = true,
    )));

    await tester.tap(find.byType(SetesButton));
    await tester.pump();

    expect(pressed, isFalse);
    expect(find.byType(SetesCircularProgressIndicator), findsOneWidget);
  });

  testWidgets('SetesCheckbox propaga onChanged', (tester) async {
    bool? value;
    await tester.pumpWidget(wrap(SetesCheckbox(
      label: 'Definir como padrão',
      value: false,
      onChanged: (v) => value = v,
    )));

    await tester.tap(find.byType(SetesCheckbox));
    await tester.pump();

    expect(value, isTrue);
  });

  // showSetesLookup: avatar mostra o itemId por padrão; com itemAvatar mostra
  // o texto dado (código oficial com zero à esquerda — ex.: CST '000').
  Future<void> openLookup(WidgetTester tester,
      {String Function(String item)? itemAvatar}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showSetesLookup<String>(
              context: context,
              title: 'Lista',
              filterHint: 'Filtro',
              emptyText: 'Vazio',
              onSearch: (_) async => ['000001'],
              itemId: (code) => int.parse(code),
              itemLabel: (code) => 'Código $code',
              itemAvatar: itemAvatar,
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('showSetesLookup sem itemAvatar mostra o itemId no avatar',
      (tester) async {
    await openLookup(tester);
    expect(
        find.descendant(
            of: find.byType(CircleAvatar), matching: find.text('1')),
        findsOneWidget);
  });

  testWidgets('showSetesLookup com itemAvatar mostra o texto dado',
      (tester) async {
    await openLookup(tester, itemAvatar: (code) => code.substring(0, 3));
    expect(
        find.descendant(
            of: find.byType(CircleAvatar), matching: find.text('000')),
        findsOneWidget);
    expect(find.text('Código 000001'), findsOneWidget);
  });
}
