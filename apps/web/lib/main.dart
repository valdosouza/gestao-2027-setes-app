import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'app/app_module.dart';
import 'app/app_widget.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
