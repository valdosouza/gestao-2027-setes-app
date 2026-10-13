import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../error/failure.dart';
import 'product_token.dart';

/// Cliente HTTP de UMA API do produto: injeta o JWT e decodifica o envelope
/// `{ ok, data }`. O app NUNCA acessa o banco (decisão 1).
///
/// D-F138 (F2b, Valdo 2026-10-13): uma classe, N instâncias — uma por base
/// de URL (setes-api = [ApiClient]; nfse-api = [NfseApiClient]) — e o token
/// num [ProductToken] ÚNICO, lido a cada requisição. [token] continua sendo a
/// porta de escrita/leitura (atalho para o [ProductToken] — as escritas do
/// login/guard/logout não mudam). 401 numa requisição que LEVOU o token da
/// sessão = a sessão morreu: [ProductToken.expire] avisa o app (limpa e volta
/// ao login — uma vez, para todas as APIs).
class ApiClient {
  ApiClient({
    http.Client? client,
    this.baseUrl = AppConfig.baseApiUrl,
    ProductToken? session,
  })  : _client = client ?? http.Client(),
        session = session ?? ProductToken();

  final http.Client _client;
  final String baseUrl;

  /// O token do produto (compartilhado entre os clientes das N APIs).
  final ProductToken session;

  String? get token => session.value;
  set token(String? value) => session.value = value;

  Future<Map<String, dynamic>> get(String path) async =>
      _send((h) => _client.get(Uri.parse('$baseUrl$path'), headers: h));

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? overrideToken,
  }) async =>
      _send(
        (h) => _client.post(Uri.parse('$baseUrl$path'), headers: h, body: jsonEncode(body)),
        overrideToken: overrideToken,
      );

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async =>
      _send((h) => _client.put(Uri.parse('$baseUrl$path'), headers: h, body: jsonEncode(body)));

  Future<Map<String, dynamic>> delete(String path) async =>
      _send((h) => _client.delete(Uri.parse('$baseUrl$path'), headers: h));

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function(Map<String, String> headers) run, {
    String? overrideToken,
  }) async {
    // o token da SESSÃO que esta requisição leva (o de seleção do login —
    // overrideToken — não é sessão: o 401 dele não expira nada)
    final sessionToken = overrideToken == null ? session.value : null;
    final bearer = overrideToken ?? sessionToken;
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (bearer != null) 'Authorization': 'Bearer $bearer',
    };
    late http.Response response;
    try {
      response = await run(headers);
    } catch (e) {
      throw NetworkFailure(detail: e.toString());
    }

    Map<String, dynamic> json;
    try {
      json = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      // corpo que não é o envelope da casa (proxy, página de erro) — nunca
      // derruba a tela com FormatException: vira falha técnica com o status
      json = <String, dynamic>{};
    }

    // Contrato do Framework de Mensagens: `{ error, code?, ref?, fields[] }` —
    // code = catálogo de erros conhecidos (R8); ref = rastro do erro técnico
    // na tb_crashlytics central (R2). Mensagens default são CHAVES i18n
    // core.errors.* (a ponte de feedback traduz; chave inexistente passa
    // a própria string, então o PT do backend chega intacto).
    if (response.statusCode == 401) {
      if (sessionToken != null) session.expire(sessionToken);
      throw UnauthorizedFailure(
        message: (json['error'] as String?) ?? 'core.errors.unauthorized',
        code: json['code'] as String?,
        supportRef: json['ref'] as String?,
      );
    }
    if (response.statusCode >= 400) {
      throw Failure(
        message: (json['error'] as String?) ?? 'core.errors.generic',
        statusCode: response.statusCode,
        fields: (json['fields'] as List<dynamic>? ?? [])
            .map((e) => FailureField.fromJson(e as Map<String, dynamic>))
            .toList(),
        code: json['code'] as String?,
        supportRef: json['ref'] as String?,
      );
    }
    return json;
  }
}

/// Cliente da nfse-api (D-F4/D-F138): o MESMO [ProductToken] do login (RS256
/// — a nfse-api só tem a chave pública) e a base `NFSE_API_URL` (D-F146 —
/// `--dart-define`; vazia = configuração faltando, ver
/// [AppConfig.missingConfiguration]). Tipo próprio só para a injeção de
/// dependências: datasource da nfse-api pede [NfseApiClient], nunca o
/// [ApiClient] do setes-api (D-F4: nunca cruza).
class NfseApiClient extends ApiClient {
  NfseApiClient({
    super.client,
    super.baseUrl = AppConfig.nfseApiUrl,
    super.session,
  });
}
