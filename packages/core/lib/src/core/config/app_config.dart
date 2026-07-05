/// Fonte única da verdade para configuração (Agent_Context_App.md:
/// "Não duplicar constantes (ex: baseApiUrl)").
class AppConfig {
  const AppConfig._();

  /// setes-api (porta 3000). Sobrescreva com --dart-define=API_URL=...
  static const String baseApiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:3000',
  );
}
