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

  /// nfse-api (D-F4/D-F146, F2b — Valdo 2026-10-13): o app fala DIRETO com a
  /// API da NFS-e. Mesma origem de configuração do [baseApiUrl] (apps/web/.env
  /// → `NFSE_API_URL`; build publicado com `--dart-define`), mas SEM padrão:
  /// um build sem a URL não pode "funcionar pela metade" falando com um
  /// endereço inventado — [missingConfiguration] faz o app FALHAR ALTO na
  /// abertura (main.dart).
  static const String nfseApiUrl = String.fromEnvironment('NFSE_API_URL');

  /// Nomes das definições obrigatórias ausentes deste build (vazio = ok).
  static List<String> missingConfiguration() => [
        if (nfseApiUrl.isEmpty) 'NFSE_API_URL',
      ];
}
