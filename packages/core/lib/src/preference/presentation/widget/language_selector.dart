import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../domain/usecase/save_preference_usecase.dart';

/// Seletor de idioma (decisões 13 e 14): troca o locale em runtime via
/// easy_localization e, quando [persist] é true (pós-login), grava a
/// preferência 'locale' na API — o idioma segue o usuário em qualquer
/// dispositivo. No login use persist: false (ainda não há JWT).
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({this.persist = true, this.saveUsecase, super.key});

  final bool persist;

  /// Optional usecase for tests; when null, uses `Modular.get<SavePreferenceUsecase>()`.
  final SavePreferenceUsecase? saveUsecase;

  static const Map<String, String> _labels = {'pt': 'Português', 'en': 'English'};

  Future<void> _change(BuildContext context, Locale locale) async {
    await context.setLocale(locale);
    if (persist) {
      final usecase = saveUsecase ?? Modular.get<SavePreferenceUsecase>();
      await usecase('locale', locale.languageCode); // falha silenciosa: locale local já mudou
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = context.locale;
    return PopupMenuButton<Locale>(
      tooltip: _labels[current.languageCode] ?? current.languageCode,
      icon: const Icon(Icons.language_outlined),
      onSelected: (locale) => _change(context, locale),
      itemBuilder: (context) => [
        for (final locale in context.supportedLocales)
          CheckedPopupMenuItem<Locale>(
            value: locale,
            checked: locale.languageCode == current.languageCode,
            child: Text(_labels[locale.languageCode] ?? locale.languageCode),
          ),
      ],
    );
  }
}
