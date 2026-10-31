// Login × troca de largura — mesmo defeito do shell da casa (onda D da densidade, `prompt_densidade_layout_web.md` §5 item 7):
// a `LoginPage` (core) escolhia entre `ContentLoginDesktop` e `ContentLoginMobile` pelo `Responsive` — duas árvores. Ao cruzar
// 1100 px com o login aberto (maximizar ou restaurar a janela; comum na máquina do Valdo, com o Windows em 125 %) o `LoginForm`
// nascia de novo e o usuário e a senha digitados sumiam. O teste sobe a `LoginPage` REAL (com o `EasyLocalization` de verdade —
// o seletor de idioma lê `context.locale` — e o logo da Setes, asset que só o app declara; por isso o teste mora no app) e prova:
// 1366 → 800 → 1366 com os dois campos, as marcações e o foco intactos, e o formulário é o MESMO (o estado não renasce).
// ⚠️ Com o campo focado o cursor pisca para sempre: depois do foco, só `pump` com duração (nunca `pumpAndSettle`).
import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
// ignore: implementation_imports
import 'package:core/src/auth/presentation/content/login_form.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _AuthRepo extends Mock implements AuthRepository {}

class _Prefs extends LocalPrefs {
  @override
  Future<String?> getRememberedEmail() async => null;
  @override
  Future<bool> getKeepConnected() async => false;
}

/// Traduções do próprio app, sem ir ao disco no relógio falso do teste.
class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('assets/translations/${locale.languageCode}.json').readAsStringSync()) as Map<String, dynamic>;
}

Future<void> _resize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  // Sem `EasyLocalization.ensureInitialized()`: com `saveLocale: false` o widget nunca lê o idioma salvo (nem toca o
  // SharedPreferences, que o app não declara como dependência).
  setUpAll(() => EasyLocalization.logger.enableBuildModes = []);

  testWidgets('o login sobrevive a 1366 → 800 → 1366 com usuário, senha, marcações e foco intactos', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1366, 768);
    addTearDown(tester.view.reset);
    // A fonte do teste (Ahem) desenha cada letra como um quadrado do tamanho da fonte: "Lembrar credenciais" + "Esqueci minha
    // senha" estouraria os 400 px do formulário SÓ no teste. Meia escala devolve larguras próximas das da fonte real.
    tester.platformDispatcher.textScaleFactorTestValue = 0.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final repo = _AuthRepo();
    final bloc = AuthBloc(
      loginUsecase: LoginUsecase(repository: repo),
      selectUsecase: SelectInstitutionUsecase(repository: repo),
      recoveryUsecase: RecoveryPasswordUsecase(repository: repo),
      changePasswordUsecase: ChangePasswordUsecase(repository: repo),
      apiClient: ApiClient(baseUrl: 'http://api.teste'),
      localPrefs: _Prefs(),
    );

    await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('pt'), Locale('en')],
      path: 'assets/translations',
      assetLoader: const _Translations(),
      startLocale: const Locale('pt'),
      fallbackLocale: const Locale('pt'),
      saveLocale: false,
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: LoginPage(bloc: bloc),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final fields = find.byType(EditableText);
    expect(fields, findsNWidgets(2), reason: 'usuário e senha');
    EditableText field(int i) => tester.widget<EditableText>(fields.at(i));
    final formState = tester.state(find.byType(LoginForm));

    await tester.enterText(fields.at(0), 'usuario.teste');
    await tester.enterText(fields.at(1), 'senha-de-teste');
    await tester.tap(find.byType(Checkbox).first); // "Lembrar credenciais"
    await tester.pump();
    await tester.tap(fields.at(1));
    await tester.pump();

    void expectIntact(String reason) {
      expect(field(0).controller.text, 'usuario.teste', reason: '$reason — usuário');
      expect(field(1).controller.text, 'senha-de-teste', reason: '$reason — senha');
      expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isTrue, reason: '$reason — "Lembrar credenciais"');
      expect(field(1).focusNode.hasFocus, isTrue, reason: '$reason — o cursor segue na senha');
      expect(identical(tester.state(find.byType(LoginForm)), formState), isTrue,
          reason: '$reason — o formulário é o MESMO (o estado não renasce)');
    }

    expectIntact('1366 px');
    // Restaurar a janela: cruza o breakpoint de 1100 px.
    await _resize(tester, const Size(800, 600));
    expectIntact('800 px (cruzou o breakpoint)');
    // Maximizar de novo.
    await _resize(tester, const Size(1366, 768));
    expectIntact('de volta a 1366 px');

    tester.takeException();
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(bloc.close);
  });
}
