import 'package:flutter/material.dart';

import '../../../preference/presentation/widget/language_selector.dart';
import '../bloc/auth_bloc.dart';
import 'auth_styles.dart';
import 'login_form.dart';

/// Tela de login com UMA árvore para todas as larguras: só a MOLDURA muda com a área útil (`LayoutBuilder`) — a partir de
/// [wideMinWidth] o formulário tem 400 px fixos; abaixo, ocupa a largura com 24 px de margem.
///
/// ⚠️ CONHECIMENTO NEGATIVO (onda D da densidade, `Infra-IA/prompts/prompt_densidade_layout_web.md`): o login escolhia entre
/// `ContentLoginDesktop` e `ContentLoginMobile` pelo `Responsive` — duas árvores. Ao cruzar 1100 px com o login aberto
/// (maximizar ou restaurar a janela) o [LoginForm] nascia de novo e o usuário e a senha digitados sumiam. Aqui o [LoginForm]
/// fica SEMPRE na mesma posição: os widgets da moldura existem nas duas larguras e só mudam de medida. Prova:
/// `apps/web/test/login_resize_test.dart`.
class ContentLogin extends StatelessWidget {
  const ContentLogin({required this.bloc, super.key});

  final AuthBloc bloc;

  /// O mesmo limite do antigo `Responsive` (desktop ≥ 1100), agora medido pela área útil.
  static const double wideMinWidth = 1100;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: AuthStyles.background(context),
          child: LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth >= wideMinWidth;
            return Stack(
              children: [
                // Sem JWT ainda: só troca o locale local (decisão 13)
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: EdgeInsets.all(wide ? 12 : 8),
                    child: const IconTheme(
                      data: IconThemeData(color: Colors.white),
                      child: LanguageSelector(persist: false),
                    ),
                  ),
                ),
                Center(
                  child: SingleChildScrollView(
                    // Nunca `null`: com padding nulo o scroll tira o `Padding` da árvore e o formulário muda de posição.
                    padding: EdgeInsets.all(wide ? 0 : 24),
                    child: SizedBox(
                      width: wide ? 400 : null,
                      child: LoginForm(bloc: bloc),
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      );
}
