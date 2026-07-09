import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../preference/presentation/widget/language_selector.dart';
import '../bloc/auth_bloc.dart';
import 'login_form.dart';

class ContentLoginMobile extends StatelessWidget {
  const ContentLoginMobile({required this.bloc, super.key});

  final AuthBloc bloc;

  @override
  Widget build(BuildContext context) => SetesScaffold(
        body: Stack(
          children: [
            // Sem JWT ainda: só troca o locale local (decisão 13)
            const Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(8),
                child: LanguageSelector(persist: false),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: LoginForm(bloc: bloc),
              ),
            ),
          ],
        ),
      );
}
