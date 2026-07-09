import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../../preference/presentation/widget/language_selector.dart';
import '../bloc/auth_bloc.dart';
import '../content/auth_field.dart';
import '../content/auth_styles.dart';

/// "Esqueci minha senha" (fluxo weberpsetes): informa o e-mail, a API gera
/// o código e a UI segue para a tela de alteração.
class RecoveryPasswordPage extends StatefulWidget {
  const RecoveryPasswordPage({super.key, this.bloc});

  /// Optional bloc for tests; when null, uses `Modular.get<AuthBloc>()`.
  final AuthBloc? bloc;

  @override
  State<RecoveryPasswordPage> createState() => _RecoveryPasswordPageState();
}

class _RecoveryPasswordPageState extends State<RecoveryPasswordPage> {
  late final AuthBloc bloc;
  final _email = TextEditingController();

  @override
  void initState() {
    super.initState();
    bloc = widget.bloc ?? Modular.get<AuthBloc>();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Widget _form(BuildContext context, AuthState state) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Image.asset('assets/images/logo_setes.png', height: 70, fit: BoxFit.contain),
          const SizedBox(height: 16),
          Text('auth.recoveryTitle'.tr(),
              textAlign: TextAlign.center,
              style: AuthStyles.label.copyWith(fontSize: 20)),
          const SizedBox(height: 8),
          Text('auth.recoveryInfo'.tr(),
              textAlign: TextAlign.center, style: AuthStyles.hint),
          const SizedBox(height: 24),
          AuthField(
            label: 'auth.email'.tr(),
            hint: 'auth.emailHint'.tr(),
            controller: _email,
            icon: Icons.email,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: 'auth.sendCode'.tr(),
            loading: state is AuthLoading,
            onPressed: () => bloc.add(AuthRecoveryRequested(email: _email.text.trim())),
          ),
          TextButton(
            onPressed: () => Modular.to.navigate('/login'),
            child: Text('auth.backToLogin'.tr(),
                style: AuthStyles.input.copyWith(
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white)),
          ),
          if (state is AuthError)
            Text(state.message,
                textAlign: TextAlign.center,
                style: AuthStyles.label.copyWith(color: Colors.amberAccent)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      bloc: bloc,
      listener: (context, state) {
        if (state is AuthRecoveryEmailSent) {
          Modular.to.pushNamed('/change-password');
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
