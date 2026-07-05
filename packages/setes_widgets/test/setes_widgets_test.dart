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
}
