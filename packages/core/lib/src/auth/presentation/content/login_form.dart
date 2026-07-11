import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../bloc/auth_bloc.dart';
import 'auth_field.dart';
import 'auth_styles.dart';

/// Formulário de login (visual weberpsetes: labels brancos, caixas
/// translúcidas, botão verde ENTRAR). Compartilhado pelos contents
/// mobile/desktop.
class LoginForm extends StatefulWidget {
  const LoginForm({required this.bloc, super.key});

  final AuthBloc bloc;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _remember = false;
  bool _keepConnected = false;

  @override
  void initState() {
    super.initState();
    // "Lembrar credenciais": pré-preenche o usuário salvo localmente.
    // (Por segurança a SENHA não é gravada — só o usuário.)
    widget.bloc.localPrefs.getRememberedEmail().then((saved) {
      if (mounted && saved != null && saved.isNotEmpty) {
        setState(() {
          _email.text = saved;
          _remember = true;
        });
      }
    });
    // "Manter conectado": lembra a última escolha do usuário
    widget.bloc.localPrefs.getKeepConnected().then((keep) {
      if (mounted && keep) setState(() => _keepConnected = true);
    });
  }

  Future<void> _submit() async {
    await widget.bloc.localPrefs
        .setRememberedEmail(_remember ? _email.text.trim() : null);
    widget.bloc.add(AuthLoginRequested(
      email: _email.text.trim(),
      password: _password.text,
      keepConnected: _keepConnected,
    ));
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
          // Logomarca SEMPRE da Setes no login (a do cliente aparece só na
          // home — decisão 16). Contrato: o app declara este asset.
          // Logo horizontal 225×70: altura limitada à resolução nativa
          // para não desfocar no upscale
          Image.asset('assets/images/logo_setes.png', height: 70, fit: BoxFit.contain),
          const SizedBox(height: 32),
          AuthField(
            label: 'auth.user'.tr(),
            hint: 'auth.userHint'.tr(),
            controller: _email,
            icon: Icons.person,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          AuthField(
            label: 'auth.password'.tr(),
            hint: 'auth.passwordHint'.tr(),
            controller: _password,
            icon: Icons.lock,
            obscure: true,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _AuthCheckbox(
                value: _remember,
                label: 'auth.rememberMe'.tr(),
                onChanged: (v) => setState(() => _remember = v),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Modular.to.pushNamed('/recovery-password'),
                child: Text('auth.forgotPassword'.tr(),
                    style: AuthStyles.input.copyWith(
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white)),
              ),
            ],
          ),
          _AuthCheckbox(
            value: _keepConnected,
            label: 'auth.keepConnected'.tr(),
            onChanged: (v) => setState(() => _keepConnected = v),
          ),
          const SizedBox(height: 16),
          AuthPrimaryButton(
            label: 'auth.login'.tr(),
            loading: state is AuthLoading,
            onPressed: _submit,
          ),
          if (state is AuthError) ...[
            const SizedBox(height: 16),
            Text(state.message,
                textAlign: TextAlign.center,
                style: AuthStyles.label.copyWith(color: Colors.amberAccent)),
          ],
        ],
      ),
    );
  }
}

/// Checkbox branco do visual de auth (weberpsetes).
class _AuthCheckbox extends StatelessWidget {
  const _AuthCheckbox({required this.value, required this.label, required this.onChanged});

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            side: const BorderSide(color: Colors.white, width: 2),
            checkColor: Theme.of(context).colorScheme.primary,
            fillColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? Colors.white
                    : Colors.transparent),
          ),
          Text(label, style: AuthStyles.input),
        ],
      );
}
