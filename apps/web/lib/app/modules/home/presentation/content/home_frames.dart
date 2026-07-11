import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

/// Conteúdo inicial do RouterOutlet ('/home/welcome/'): nenhuma interface
/// selecionada ainda.
class WelcomeFrame extends StatelessWidget {
  const WelcomeFrame({super.key});

  @override
  Widget build(BuildContext context) =>
      Center(child: SetesText('home.welcome'.tr()));
}

/// Placeholder para interface do menu que ainda não tem módulo
/// ('/home/pending/', argumento = i18nKey/descrição da interface).
class PendingInterfaceFrame extends StatelessWidget {
  const PendingInterfaceFrame({super.key});

  @override
  Widget build(BuildContext context) {
    final key = Modular.args.data as String? ?? '';
    return Center(child: SetesText('home.not_implemented'.tr(args: [key])));
  }
}
