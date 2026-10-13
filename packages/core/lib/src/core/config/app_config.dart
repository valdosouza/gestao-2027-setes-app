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
  /// → `NFSE_API_URL`; build publicado com `--dart-define` — `build-web.ps1`),
  /// mas SEM padrão: um build sem a URL não pode "funcionar pela metade"
  /// falando com um endereço inventado — [missingConfiguration] faz o app
  /// FALHAR ALTO na abertura (main.dart).
  static const String nfseApiUrl = String.fromEnvironment('NFSE_API_URL');

  /// O que está faltando ou torto na configuração deste build (vazio = ok) —
  /// uma linha por definição, com o motivo.
  static List<String> missingConfiguration() => [
        ...urlProblems('NFSE_API_URL', nfseApiUrl),
        ...urlProblems('API_URL', baseApiUrl),
      ];

  /// Por que [value] não serve de base de API (D-F146 + gate adversarial da
  /// F2b, F2B-ADV-10): vazia; sem esquema http(s) ou sem host (a URI nunca sai
  /// do navegador e a falha pareceria "rede caída"); `http://` fora de
  /// localhost (o navegador da produção é https — e o CORS da nfse-api só
  /// aceita http em localhost); com consulta ou fragmento. Barra final é
  /// tolerada (o cliente a tira).
  static List<String> urlProblems(String name, String value) {
    final v = value.trim();
    if (v.isEmpty) return ['$name (vazia)'];
    final u = Uri.tryParse(v);
    if (u == null || (u.scheme != 'http' && u.scheme != 'https') || u.host.isEmpty) {
      return ['$name (não é uma URL http/https com host: $v)'];
    }
    if (u.scheme == 'http' && u.host != 'localhost' && u.host != '127.0.0.1') {
      return ['$name (http:// só em localhost — fora dele, https://: $v)'];
    }
    if (u.hasQuery || u.hasFragment) return ['$name (sem consulta nem fragmento: $v)'];
    return const [];
  }
}
