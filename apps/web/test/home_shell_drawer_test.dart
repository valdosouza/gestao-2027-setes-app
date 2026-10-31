// Shell da casa no celular — bug visto no passeio de 2026-10-17 (na produção também; onda D da densidade, `prompt_densidade_layout_web.md`
// §5): a 375 px o ☰ do menu não aparecia — logo + nome do usuário + idioma + tema somavam ~360 px, a barra alinhava as ações à
// direita POR CIMA do ☰ e o menu ficava sem acesso. D-DL6: a barra estreita leva só ☰ + logomarca + o botão do usuário com o ícone
// (nome, idioma, tema e Sair dentro do menu dele). O teste usa o `UserBadge` REAL com um nome longo e uma logomarca LARGA (o pior
// caso de cliente) e prova: o ☰ está na tela, nada o cobre e o toque nele abre a gaveta. Com as ações antigas (~360 px) o toque no
// ☰ cai nas ações e a gaveta não abre (conferido).
import 'package:core/core.dart';
import 'package:dartz/dartz.dart' show Right;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'support/home_shell_harness.dart';

class _AuthRepo extends Mock implements AuthRepository {}

void main() {
  setUpAll(loadPtTranslations);

  testWidgets('a 375 px o ☰ aparece, nada o cobre e o toque abre a gaveta com os módulos', (tester) async {
    final auth = _AuthRepo();
    when(auth.getMe).thenAnswer((_) async => const Right(SessionUser(
          userId: 1,
          name: 'GESTAO COMPUTACIONAL LTDA ADMINISTRADOR DO SISTEMA',
          role: 'admin',
          institutionId: 1,
          institutionName: 'Setes',
        )));
    final bloc = buildMenuBloc();
    await bootShell(
      tester,
      size: const Size(375, 812),
      shell: () => testShell(
        bloc,
        logo: testLogo(160), // logomarca larga (4:1)
        barAccount: UserBadge(compact: true, usecase: GetMeUsecase(repository: auth)),
      ),
    );

    final menu = find.byIcon(Icons.menu);
    expect(menu, findsOneWidget, reason: 'o ☰ está na barra');
    final menuRect = tester.getRect(menu);

    // O toque no CENTRO do ☰ chega nele (nada da barra o cobre) e abre a gaveta.
    await tester.tapAt(menuRect.center);
    await settleShell(tester);
    expect(find.byType(Drawer), findsOneWidget, reason: 'o toque no ☰ abre a gaveta — nada da barra o cobre');
    expect(find.text('Cadastros'), findsOneWidget, reason: 'com os módulos');
    expect(formBuilds, 1, reason: 'abrir a gaveta não recria a tela aberta');

    // Barra enxuta (D-DL6): o botão do usuário fica longe do ☰ e o nome mora dentro do menu dele.
    expect(tester.getRect(find.byType(UserBadge)).overlaps(menuRect), isFalse);
    expect(find.text('GESTAO COMPUTACIONAL LTDA ADMINISTRADOR DO SISTEMA'), findsNothing,
        reason: 'no celular o nome mora dentro do menu do usuário, não na barra');

    await tearDownShell(tester, bloc);
  });
}
