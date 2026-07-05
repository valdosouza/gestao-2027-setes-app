import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../bloc/auth_bloc.dart';
import 'login_form.dart';

class ContentLoginMobile extends StatelessWidget {
  const ContentLoginMobile({required this.bloc, super.key});

  final AuthBloc bloc;

  @override
  Widget build(BuildContext context) => SetesScaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: LoginForm(bloc: bloc),
          ),
        ),
      );
}
