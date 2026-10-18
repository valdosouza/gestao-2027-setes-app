// Shell da casa × troca de largura — bug do passeio de 2026-10-17 (onda D da densidade, `prompt_densidade_layout_web.md` §5):
// o cadastro aberto em 1366 px, redimensionado para 1093 (o notebook do Valdo com o Windows em 125 %), voltava para a LISTA e o que
// tinha sido digitado se perdia — o shell trocava a árvore inteira (`ContentHomeMobile` × `ContentHomeDesktop`) e o `RouterOutlet`
// era recriado. Aqui o shell REAL (`ContentHome`) hospeda um formulário no `RouterOutlet` e passa por todas as trocas de largura e
// de menu: 1366 → 1093 (menu ao lado desde a D-DL7) → 2ª coluna recolhida → 800 (cruza os 840: gaveta) → 1366. Mede: o texto e o
// foco sobrevivem e o formulário nasce UMA vez. Com a estrutura antiga o texto some ao cruzar o breakpoint (conferido).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setes_web/app/modules/home/presentation/bloc/menu_bloc.dart';

import 'support/home_shell_harness.dart';

void main() {
  setUpAll(loadPtTranslations);

  testWidgets('o formulário aberto sobrevive a 1366 → 1093 → (coluna recolhida) → 800 → 1366 com o texto e o foco intactos',
      (tester) async {
    final bloc = buildMenuBloc();
    await bootShell(tester, size: const Size(1366, 768), shell: () => testShell(bloc));

    final field = find.byKey(const ValueKey('name'));
    bool fieldHasFocus() =>
        tester.widget<EditableText>(find.descendant(of: field, matching: find.byType(EditableText))).focusNode.hasFocus;
    void expectIntact(String reason) {
      expect(find.text('A.S.M Alimentos'), findsOneWidget, reason: reason);
      expect(fieldHasFocus(), isTrue, reason: '$reason — e o cursor continua no campo');
    }

    expect(field, findsOneWidget);
    expect(sideMenuShown(), isTrue, reason: '1366 px: menu ao lado, sem ☰');
    // O usuário abre o módulo (2ª coluna) e começa a digitar.
    await tester.tap(find.text('Cadastros'));
    await settleShell(tester);
    expect(find.text('Clientes'), findsOneWidget, reason: '2ª coluna aberta');
    await tester.tap(field);
    await tester.enterText(field, 'A.S.M Alimentos');
    await tester.pump();
    expectIntact('1366 px');

    // Restaurar a janela no notebook em 125 %: 1093 px de área — o menu segue ao lado (D-DL7, breakpoint de 840).
    await resizeShell(tester, const Size(1093, 540));
    expect(sideMenuShown(), isTrue, reason: '1093 px: menu ao lado');
    expectIntact('1093 px');

    // Recolher a 2ª coluna com o formulário aberto.
    await tester.tap(find.byTooltip('Recolher as telas'));
    await settleShell(tester);
    expect(find.text('Clientes'), findsNothing, reason: '2ª coluna recolhida');
    expect(bloc.state, isA<MenuLoaded>().having((s) => s.interfacesCollapsed, 'recolhida', isTrue));
    expectIntact('coluna recolhida');

    // Janela estreita: cruza o breakpoint — o menu vira gaveta.
    await resizeShell(tester, const Size(800, 600));
    expect(find.byIcon(Icons.menu), findsOneWidget, reason: '800 px: menu na gaveta');
    expectIntact('800 px (cruzou o breakpoint)');

    // Maximizar de novo: cruza de volta.
    await resizeShell(tester, const Size(1366, 768));
    expect(sideMenuShown(), isTrue);
    expectIntact('de volta a 1366 px');
    expect(formBuilds, 1, reason: 'o formulário nunca é recriado pela troca de largura nem pelo menu');

    await tearDownShell(tester, bloc);
  });
}
