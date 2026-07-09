import 'package:flutter/material.dart';

import '../../../preference/presentation/widget/language_selector.dart';
import '../bloc/auth_bloc.dart';
import 'auth_styles.dart';
import 'login_form.dart';

class ContentLoginDesktop extends StatelessWidget {
  const ContentLoginDesktop({required this.bloc, super.key});

  final AuthBloc bloc;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: AuthStyles.background(context),
          child: Stack(
            children: [
              // Sem JWT ainda: só troca o locale local (decisão 13)
              const Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: IconTheme(
                    data: IconThemeData(color: Colors.white),
                    child: LanguageSelector(persist: false),
                  ),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  child: SizedBox(
                    width: 400,
                    child: LoginForm(bloc: bloc),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
