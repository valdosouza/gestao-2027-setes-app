import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../../shared/helpers/responsive.dart';
import '../bloc/auth_bloc.dart';
import '../content/content_login_desktop.dart';
import '../content/content_login_mobile.dart';

/// Tela de login (decisão 5: page com arquivos de content por breakpoint).
/// Bloc opcional para testabilidade (padrão Agent_Context_App.md).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.bloc});

  /// Optional bloc for tests; when null, uses `Modular.get<AuthBloc>()`.
  final AuthBloc? bloc;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final AuthBloc bloc;

  @override
  void initState() {
    super.initState();
    bloc = widget.bloc ?? Modular.get<AuthBloc>();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      bloc: bloc,
      listener: (context, state) {
        if (state is AuthAuthenticated) Modular.to.navigate('/home/');
        if (state is AuthNeedsSelection) Modular.to.navigate('/select-institution');
      },
      child: Responsive(
        mobile: ContentLoginMobile(bloc: bloc),
        desktop: ContentLoginDesktop(bloc: bloc),
      ),
    );
  }
}
