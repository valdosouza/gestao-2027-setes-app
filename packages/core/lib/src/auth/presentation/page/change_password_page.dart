import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../../preference/presentation/widget/language_selector.dart';
import '../bloc/auth_bloc.dart';
import '../content/auth_feedback.dart';
import '../content/auth_field.dart';
import '../content/auth_styles.dart';

/// Alteração de senha com o código recebido por e-mail (fluxo weberpsetes).
/// Acessível também DIRETO pelo link do e-mail (sessão nova): por isso o
/// campo de e-mail é visível — pré-preenchido quando se vem do fluxo interno.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key, this.bloc});

  /// Optional bloc for tests; when null, uses `Modular.get<AuthBloc>()`.
  final AuthBloc? bloc;

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  late final AuthBloc bloc;
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    bloc = widget.bloc ?? Modular.get<AuthBloc>();
    _email.text = bloc.recoveryEmail ?? '';
  }

  /// Pendência LOCAL = dialog de validação + foco de volta no campo — UMA
  /// por vez (Framework de Mensagens, R1/R3).
  Future<void> _submit() async {
    if (_password.text.length < 5) {
      await showAuthValidationDialog(context, 'auth.passwordTooShort');
      if (mounted) _passwordFocus.requestFocus();
      return;
    }
    if (_password.text != _confirm.text) {
      await showAuthValidationDialog(context, 'auth.passwordsDontMatch');
      if (mounted) _confirmFocus.requestFocus();
      return;
    }
    bloc.add(AuthChangePasswordRequested(
      email: _email.text.trim(),
      code: _code.text.trim(),
      newPassword: _password.text,
    ));
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Widget _form(BuildContext context, AuthState state) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Image.asset('assets/images/logo_setes.png', height: 70, fit: BoxFit.contain),
          const SizedBox(height: 16),
          Text('auth.changeTitle'.tr(),
              textAlign: TextAlign.center,
              style: AuthStyles.label.copyWith(fontSize: 20)),
          const SizedBox(height: 8),
          Text('auth.codeSentInfo'.tr(),
              textAlign: TextAlign.center,
              style: AuthStyles.label.copyWith(color: Colors.amberAccent)),
          const SizedBox(height: 24),
          AuthField(
            label: 'auth.email'.tr(),
            hint: 'auth.emailHint'.tr(),
            controller: _email,
            icon: Icons.email,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          AuthField(
            label: 'auth.code'.tr(),
            hint: 'auth.codeHint'.tr(),
            controller: _code,
            icon: Icons.pin,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          AuthField(
            label: 'auth.newPassword'.tr(),
            hint: 'auth.passwordHint'.tr(),
            controller: _password,
            focusNode: _passwordFocus,
            icon: Icons.lock,
            obscure: true,
          ),
          const SizedBox(height: 16),
          AuthField(
            label: 'auth.confirmPassword'.tr(),
            hint: 'auth.passwordHint'.tr(),
            controller: _confirm,
            focusNode: _confirmFocus,
            icon: Icons.lock_outline,
            obscure: true,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: 'auth.changePassword'.tr(),
            loading: state is AuthLoading,
            onPressed: _submit,
          ),
          TextButton(
            onPressed: () => Modular.to.navigate('/login'),
            child: Text('auth.backToLogin'.tr(),
                style: AuthStyles.input.copyWith(
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white)),
          ),
          if (state is AuthError && !isTechnicalFailure(state.failure))
            // .tr(): defaults do Failure são chaves core.errors.* (chave
            // inexistente devolve a própria string — PT do backend intacto).
            Text(state.message.tr(),
                textAlign: TextAlign.center,
                style: AuthStyles.label.copyWith(color: Colors.amberAccent)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      bloc: bloc,
      listener: (context, state) {
        if (state is AuthPasswordChanged) {
          // Sucesso = SnackBar via apresentador (R1) — nunca
          // ScaffoldMessenger direto na tela.
          showAuthSuccessFeedback(context, 'auth.passwordChanged');
          Modular.to.navigate('/login');
        }
        // 500/rede = dialog de erro técnico (R7); código inválido/erro
        // corrigível permanece inline no formulário.
        if (state is AuthError && isTechnicalFailure(state.failure)) {
          showAuthFailureDialog(context, state.failure);
        }
      },
      builder: (context, state) => Scaffold(
        body: Container(
          decoration: AuthStyles.background(context),
          child: Stack(
            children: [
              // Sem JWT: troca de idioma só local (decisão 13)
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
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(width: 400, child: _form(context, state)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
