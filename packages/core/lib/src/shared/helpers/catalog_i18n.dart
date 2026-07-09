import 'package:easy_localization/easy_localization.dart';

/// Tradução do catálogo vindo do banco (decisão 26 — chave i18n + fallback):
/// tenta a chave nos JSONs do app; se não existir, mostra o texto do banco.
///
/// Convenção de chaves (assets/translations/*.json do app):
/// - interfaces:   menu.interfaces.<i18n_key>     (tb_interface.i18n_key)
/// - grupos:       menu.groups.<group_default>
/// - privilégios:  menu.privileges.<description>  (tb_privilege.description)
String trCatalog(String? key, String fallback, {required String prefix}) {
  if (key == null || key.isEmpty) return fallback;
  final fullKey = '$prefix.$key';
  final translated = fullKey.tr();
  return translated == fullKey ? fallback : translated;
}
