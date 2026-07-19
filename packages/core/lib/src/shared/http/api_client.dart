import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../error/failure.dart';

/// Cliente HTTP do setes-app: injeta o JWT e decodifica o envelope
/// `{ ok, data }` da setes-api. O app NUNCA acessa o banco (decisão 1).
class ApiClient {
  ApiClient({http.Client? client, this.baseUrl = AppConfig.baseApiUrl})
      : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  String? token;

  Map<String, String> _headers({String? overrideToken}) => {
        'Content-Type': 'application/json',
        if (overrideToken != null || token != null)
          'Authorization': 'Bearer ${overrideToken ?? token}',
      };

  Future<Map<String, dynamic>> get(String path) async =>
      _send(() => _client.get(Uri.parse('$baseUrl$path'), headers: _headers()));

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? overrideToken,
  }) async =>
      _send(() => _client.post(
            Uri.parse('$baseUrl$path'),
            headers: _headers(overrideToken: overrideToken),
            body: jsonEncode(body),
          ));

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async =>
      _send(() => _client.put(
            Uri.parse('$baseUrl$path'),
            headers: _headers(),
            body: jsonEncode(body),
          ));

  Future<Map<String, dynamic>> delete(String path) async =>
      _send(() => _client.delete(Uri.parse('$baseUrl$path'), headers: _headers()));

  Future<Map<String, dynamic>> _send(Future<http.Response> Function() run) async {
    late http.Response response;
    try {
      response = await run();
    } catch (_) {
      throw const NetworkFailure();
    }

    final Map<String, dynamic> json = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    // Contrato do Framework de Mensagens: `{ error, code?, ref?, fields[] }` —
    // code = catálogo de erros conhecidos (R8); ref = rastro do 500 na
    // tb_crashlytics central (R2). Mensagens default são CHAVES i18n
    // core.errors.* (a ponte de feedback traduz; chave inexistente passa
    // a própria string, então o PT do backend chega intacto).
    if (response.statusCode == 401) {
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
