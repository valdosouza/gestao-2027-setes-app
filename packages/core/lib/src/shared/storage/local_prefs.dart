import 'package:shared_preferences/shared_preferences.dart';

/// Preferências locais do dispositivo (decisão 15): o institution padrão
/// NÃO vai ao banco — localStorage no web, SharedPreferences nos apps.
/// (Preferências que seguem o usuário — ex. locale — vão à API: decisão 14.)
class LocalPrefs {
  static const String _kDefaultInstitution = 'default_institution_id';

  Future<int?> getDefaultInstitutionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kDefaultInstitution);
  }

  Future<void> setDefaultInstitutionId(int? institutionId) async {
    final prefs = await SharedPreferences.getInstance();
    if (institutionId == null) {
      await prefs.remove(_kDefaultInstitution);
    } else {
      await prefs.setInt(_kDefaultInstitution, institutionId);
    }
  }
}
