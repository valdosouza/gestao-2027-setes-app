import 'package:shared_preferences/shared_preferences.dart';

/// Preferências locais do dispositivo (decisão 15): o institution padrão
/// NÃO vai ao banco — localStorage no web, SharedPreferences nos apps.
/// (Preferências que seguem o usuário — ex. locale — vão à API: decisão 14.)
class LocalPrefs {
  static const String _kDefaultInstitution = 'default_institution_id';
  static const String _kRememberedEmail = 'remembered_email';
  static const String _kSessionToken = 'session_token';
  static const String _kKeepConnected = 'keep_connected';

  /// Escolha do usuário no login: manter conectado entre sessões.
  Future<bool> getKeepConnected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kKeepConnected) ?? false;
  }

  Future<void> setKeepConnected(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kKeepConnected, value);
  }

  /// Sessão sobrevive ao refresh do navegador: o JWT (TTL 24h — decisão 19
  /// da Fase 2) é persistido e restaurado pelo SetesAuthGuard.
  Future<String?> getSessionToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kSessionToken);
  }

  Future<void> setSessionToken(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null || token.isEmpty) {
      await prefs.remove(_kSessionToken);
    } else {
      await prefs.setString(_kSessionToken, token);
    }
  }

  /// "Lembrar credenciais" do login: guarda só o USUÁRIO (nunca a senha).
  Future<String?> getRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kRememberedEmail);
  }

  Future<void> setRememberedEmail(String? email) async {
    final prefs = await SharedPreferences.getInstance();
    if (email == null || email.isEmpty) {
      await prefs.remove(_kRememberedEmail);
    } else {
      await prefs.setString(_kRememberedEmail, email);
    }
  }

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
