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

  /// Nome do idioma no próprio idioma (ex.: "Português").
  static String labelOf(Locale locale) => _labels[locale.languageCode] ?? locale.languageCode;

  /// Troca o idioma — o MESMO caminho do seletor, para quem oferece o idioma em
  /// outro lugar (ex.: o menu do usuário no celular — onda D da densidade).
  /// [context] precisa seguir montado depois da escolha (nunca o de um popup).
  static Future<void> change(
    BuildContext context,
    Locale locale, {
    bool persist = true,
    SavePreferenceUsecase? saveUsecase,
  }) async {
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
      tooltip: labelOf(current),
      icon: const Icon(Icons.language_outlined),
      onSelected: (locale) => change(context, locale, persist: persist, saveUsecase: saveUsecase),
      itemBuilder: (context) => [
        for (final locale in context.supportedLocales)
          CheckedPopupMenuItem<Locale>(
            value: locale,
            checked: locale.languageCode == current.languageCode,
            child: Text(labelOf(locale)),
          ),
      ],
    );
  }
}
