import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setes_widgets/setes_widgets.dart';

/// Onda B da densidade (2026-10-17): a grade decide a largura pela área
/// DISPONÍVEL e mantém a ordem declarada dos campos.
void main() {
  Future<void> pumpGrid(
    WidgetTester tester, {
    required double width,
    required List<SetesFieldSize> sizes,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SetesFormGrid(items: [
          for (final (index, size) in sizes.indexed)
            SetesFormGridItem(
              size: size,
              child: SizedBox(key: ValueKey(index), height: 40),
            ),
        ]),
      ),
    ));
  }

  Rect rectOf(WidgetTester tester, int index) =>
      tester.getRect(find.byKey(ValueKey(index)));

  test('spanOf: celular = linha inteira; média e expandida pelo tamanho', () {
    for (final size in SetesFieldSize.values) {
      expect(SetesFormGrid.spanOf(size, 599), 12);
    }
    expect(SetesFormGrid.spanOf(SetesFieldSize.small, 700), 4);
    expect(SetesFormGrid.spanOf(SetesFieldSize.large, 700), 12);
    expect(SetesFormGrid.spanOf(SetesFieldSize.small, 840), 3);
    expect(SetesFormGrid.spanOf(SetesFieldSize.medium, 840), 4);
    expect(SetesFormGrid.spanOf(SetesFieldSize.large, 840), 6);
    expect(SetesFormGrid.spanOf(SetesFieldSize.full, 840), 12);
  });

  testWidgets('expandida: 2 nomes numa linha, 4 documentos na seguinte',
      (tester) async {
    const l = SetesFieldSize.large;
    const s = SetesFieldSize.small;
    await pumpGrid(tester, width: 1000, sizes: [l, l, s, s, s, s]);

    expect(rectOf(tester, 0).top, rectOf(tester, 1).top);
    expect(rectOf(tester, 2).top, greaterThan(rectOf(tester, 1).top));
    for (final i in [3, 4, 5]) {
      expect(rectOf(tester, i).top, rectOf(tester, 2).top);
    }
    // ordem de leitura preservada: da esquerda para a direita
    expect(rectOf(tester, 1).left, greaterThan(rectOf(tester, 0).left));
    expect(rectOf(tester, 5).left, greaterThan(rectOf(tester, 4).left));
    // nada passa da largura disponível
    expect(rectOf(tester, 1).right, lessThanOrEqualTo(1000));
    expect(rectOf(tester, 5).right, lessThanOrEqualTo(1000));
    expect(tester.takeException(), isNull);
  });

  testWidgets('celular: cada campo na linha inteira, como antes',
      (tester) async {
    await pumpGrid(tester,
        width: 400, sizes: [SetesFieldSize.small, SetesFieldSize.large]);

    expect(rectOf(tester, 0).width, 400);
    expect(rectOf(tester, 1).width, 400);
    expect(rectOf(tester, 1).top, greaterThan(rectOf(tester, 0).top));
  });

  testWidgets('monitor grande: o formulário para na largura máxima',
      (tester) async {
    await pumpGrid(tester,
        width: 2000, sizes: [SetesFieldSize.full, SetesFieldSize.large]);

    expect(rectOf(tester, 0).width,
        lessThanOrEqualTo(SetesFormGrid.maxContentWidth));
    expect(rectOf(tester, 0).left, 0); // alinhado à esquerda
  });

  testWidgets('item que não cabe no resto da linha abre linha nova',
      (tester) async {
    const m = SetesFieldSize.medium;
    const l = SetesFieldSize.large;
    // 4 + 6 = 10; o próximo medium (4) não cabe nos 2 que sobram
    await pumpGrid(tester, width: 1000, sizes: [m, l, m]);

    expect(rectOf(tester, 1).top, rectOf(tester, 0).top);
    expect(rectOf(tester, 2).top, greaterThan(rectOf(tester, 0).top));
    expect(rectOf(tester, 2).left, 0);
  });
}
