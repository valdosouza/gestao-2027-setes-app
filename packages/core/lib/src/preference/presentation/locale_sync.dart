import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../domain/usecase/get_preferences_usecase.dart';

/// Aplica o idioma salvo do usuário (tb_user_has_preference.locale) após o
/// login (decisão 14). Chamar na home, pós-frame. Silencioso em caso de falha.
Future<void> applyUserLocale(BuildContext context, GetPreferencesUsecase usecase) async {
  final result = await usecase();
  await result.fold(
    (_) async {},
    (prefs) async {
      final saved = prefs['locale'];
      if (saved == null || saved.isEmpty) return;
      if (!context.mounted) return;
      final target = Locale(saved);
      final supported = context.supportedLocales
          .any((l) => l.languageCode == target.languageCode);
      if (supported && context.locale.languageCode != target.languageCode) {
        await context.setLocale(target);
      }
    },
  );
}
