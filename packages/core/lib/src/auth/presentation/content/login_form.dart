import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../bloc/auth_bloc.dart';

/// Formulário compartilhado pelos contents mobile/desktop
/// (somente widgets Setes* — decisão 11).
class LoginForm extends StatefulWidget {
  const LoginForm({required this.bloc, super.key});

  final AuthBloc bloc;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  void _submit() {
    widget.bloc.add(AuthLoginRequested(email: _email.text.trim(), password: _password.text));
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      bloc: widget.bloc,
      builder: (context, state) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SetesText.title('app.title'.tr()),
          const SizedBox(height: 24),
          SetesTextField(
            label: 'auth.email'.tr(),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.mail_outline,
          ),
          const SizedBox(height: 16),
          SetesTextField(
            label: 'auth.password'.tr(),
            controller: _password,
            obscureText: true,
            prefixIcon: Icons.lock_outline,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 24),
          SetesButton(
            label: 'auth.login'.tr(),
            loading: state is AuthLoading,
            onPressed: _submit,
          ),
          if (state is AuthError) ...[
            const SizedBox(height: 16),
            SetesText(state.message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
    );
  }
}
