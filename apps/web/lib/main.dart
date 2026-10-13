import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'app/app_module.dart';
import 'app/app_widget.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // D-F146 (F2b): build sem a configuração obrigatória (a URL da nfse-api)
  // FALHA ALTO na abertura — nunca um app "pela metade" chamando um endereço
  // inventado (a NFS-e quebraria só no 1º clique, longe da causa).
  final missing = AppConfig.missingConfiguration();
  if (missing.isNotEmpty) {
    runApp(_MissingConfigurationApp(missing));
    return;
  }

  // i18n (decisão 13): easy_localization com JSON, troca em runtime.
  // O locale do usuário é sincronizado com GET/PUT /api/core/preferences
  // (chave 'locale' — decisão 14) após o login.
  await EasyLocalization.ensureInitialized();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('pt'), Locale('en')],
      path: 'assets/translations',
      // Produto nasce em pt: sem startLocale o easy_localization segue o
      // idioma do BROWSER (en vira app em inglês). A troca por usuário é a
      // sincronização com /api/core/preferences (decisão 14 — pendente).
      startLocale: const Locale('pt'),
      fallbackLocale: const Locale('pt'),
      child: ModularApp(module: AppModule(), child: const AppWidget()),
    ),
  );
}

/// Tela de erro de CONFIGURAÇÃO do build (antes do i18n e do login — texto
/// fixo): diz o que falta e como o build deve ser gerado.
class _MissingConfigurationApp extends StatelessWidget {
  const _MissingConfigurationApp(this.missing);

  final List<String> missing;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Build sem configuração obrigatória: ${missing.join(', ')}.\n'
                'Gere o app com --dart-define (ou --dart-define-from-file=.env) '
                'informando o endereço de cada API do produto.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
}
