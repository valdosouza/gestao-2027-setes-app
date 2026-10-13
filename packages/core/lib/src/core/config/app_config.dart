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

  /// Host DNS (rótulos) ou IP (o `Uri.host` do IPv6 vem sem colchetes).
  static final _dnsHost = RegExp(r'^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$');
  static final _ipv6Host = RegExp(r'^[0-9a-f:.]+$');
  // WHATWG: host cujo ÚLTIMO rótulo é número (decimal ou 0x…) é parseado como
  // IPv4 — inválido, o navegador RECUSA a URL (R5-ADV-08)
  static final _numericLabel = RegExp(r'^(\d+|0x[0-9a-f]*)$');
  static final _ipv4Octet = RegExp(r'^(0|[1-9]\d{0,2})$');

  /// Por que [value] não serve de base de API (D-F146 + gate adversarial da
  /// F2b, F2B-ADV-10): vazia; sem esquema http(s) ou sem host (a URI nunca sai
  /// do navegador e a falha pareceria "rede caída"); `http://` fora de
  /// localhost (o navegador da produção é https — e o CORS da nfse-api só
  /// aceita http em localhost); com consulta ou fragmento. Barra final é
  /// tolerada (o cliente a tira). Também o que o NAVEGADOR recusa e o Dart
  /// aceita (F2B-RG-08): credenciais na URL, porta fora da faixa, host torto.
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
    // o que o NAVEGADOR recusa e o Dart aceita (F2B-RG-08): sem isto cada ato
    // viraria NetworkFailure = "desfecho desconhecido"
    if (u.userInfo.isNotEmpty) return ['$name (sem credenciais na URL: $v)'];
    if (u.hasPort && (u.port < 1 || u.port > 65535)) return ['$name (porta fora de 1–65535: $v)'];
    if (!_dnsHost.hasMatch(u.host) && !_ipv6Host.hasMatch(u.host)) return ['$name (host fora da forma DNS/IP: $v)'];
    if (!u.host.contains(':')) {
      final labels = u.host.split('.');
      final ipv4 = labels.length == 4 && labels.every((l) => _ipv4Octet.hasMatch(l) && int.parse(l) <= 255);
      if (_numericLabel.hasMatch(labels.last) && !ipv4) {
        return ['$name (host termina em número e não é um IPv4 válido — o navegador recusa: $v)'];
      }
    }
    if (u.host == '0.0.0.0' || u.host == '::') return ['$name (endereço não especificado — não é um servidor: $v)'];
    return const [];
  }
}
