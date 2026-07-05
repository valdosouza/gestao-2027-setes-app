import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../bloc/auth_bloc.dart';
import 'login_form.dart';

class ContentLoginDesktop extends StatelessWidget {
  const ContentLoginDesktop({required this.bloc, super.key});

  final AuthBloc bloc;

  @override
  Widget build(BuildContext context) => SetesScaffold(
        body: Center(
          child: SizedBox(
            width: 420,
            child: SetesCard(
              padding: const EdgeInsets.all(32),
              child: LoginForm(bloc: bloc),
            ),
          ),
        ),
      );
}
