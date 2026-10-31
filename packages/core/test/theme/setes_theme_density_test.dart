import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Onda A da densidade (2026-10-17): densidade FIXA por plataforma —
/// compacta com mouse/teclado, padrão do Material no toque.
void main() {
  test('compacta: campo denso de 14 px, barras de 48, listas apertadas', () {
    final theme = SetesTheme.build(compact: true);

    expect(theme.visualDensity, VisualDensity.compact);
    expect(theme.inputDecorationTheme.isDense, isTrue);
    expect(theme.inputDecorationTheme.contentPadding, SetesDensity.fieldPadding);
    // rótulo flutuante: 16 × 0,75 do Material = 12 px, como era
    expect(theme.inputDecorationTheme.floatingLabelStyle?.fontSize,
        SetesDensity.floatingLabelFontSize);
    expect(theme.appBarTheme.toolbarHeight, SetesDensity.toolbarHeight);
    expect(theme.textTheme.bodyLarge?.fontSize, SetesDensity.fieldFontSize);
    expect(theme.listTileTheme.visualDensity, SetesDensity.listDensity);
  });

  test('padrão (toque): nada muda em relação ao Material', () {
    final theme = SetesTheme.build(compact: false);

    expect(theme.visualDensity, VisualDensity.standard);
    expect(theme.inputDecorationTheme.isDense, isFalse);
    expect(theme.appBarTheme.toolbarHeight, isNull);
    // sem sobreposição: o tamanho vem da tipografia do M3 (16) no Theme.of
    expect(theme.textTheme.bodyLarge?.fontSize, isNull);
    expect(theme.listTileTheme.visualDensity, isNull);
  });

  test('sem escolha explícita, decide pela plataforma', () {
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(SetesTheme.build().inputDecorationTheme.isDense, isTrue);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(SetesTheme.build().inputDecorationTheme.isDense, isFalse);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('campo de texto compacto fica mais baixo que o padrão',
      (tester) async {
    Future<double> fieldHeight(bool compact) async {
      await tester.pumpWidget(MaterialApp(
        theme: SetesTheme.build(compact: compact),
        home: const Scaffold(
          body: TextField(
            decoration: InputDecoration(
              labelText: 'Razão Social',
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle(); // o MaterialApp anima a troca de tema
      return tester.getSize(find.byType(TextField)).height;
    }

    final standard = await fieldHeight(false);
    final compact = await fieldHeight(true);
    expect(standard, 56); // Material 3 no toque
    expect(compact, inInclusiveRange(38, 42)); // ~41 px no desktop
  });
}
