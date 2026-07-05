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

  String? _token;

  set token(String? value) => _token = value;
  String? get token => _token;

  Map<String, String> _headers({String? overrideToken}) => {
        'Content-Type': 'application/json',
        if (overrideToken != null || _token != null)
          'Authorization': 'Bearer ${overrideToken ?? _token}',
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

    if (response.statusCode == 401) {
      throw UnauthorizedFailure(message: (json['error'] as String?) ?? 'Não autorizado');
    }
    if (response.statusCode >= 400) {
      throw Failure(
        message: (json['error'] as String?) ?? 'Erro ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
    return json;
  }
}
