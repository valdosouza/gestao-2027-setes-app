/// Fonte única da verdade para configuração (Agent_Context_App.md:
/// "Não duplicar constantes (ex: baseApiUrl)").
class AppConfig {
  const AppConfig._();

  /// setes-api. Em dev vem do apps/web/.env (API_URL) via run-dev.ps1
  /// (--dart-define-from-file); sobrescritível com --dart-define=API_URL=...
  static const String baseApiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:3000',
  );
}
