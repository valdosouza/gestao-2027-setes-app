import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../preference/presentation/widget/language_selector.dart';
import '../bloc/auth_bloc.dart';
import 'login_form.dart';

class ContentLoginDesktop extends StatelessWidget {
  const ContentLoginDesktop({required this.bloc, super.key});

  final AuthBloc bloc;

  @override
  Widget build(BuildContext context) => SetesScaffold(
        body: Stack(
          children: [
            // Sem JWT ainda: só troca o locale local (decisão 13)
            const Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: LanguageSelector(persist: false),
              ),
            ),
            Center(
              child: SizedBox(
                width: 420,
                child: SetesCard(
                  padding: const EdgeInsets.all(32),
                  child: LoginForm(bloc: bloc),
                ),
              ),
            ),
          ],
        ),
      );
}
