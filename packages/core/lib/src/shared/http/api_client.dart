import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../error/failure.dart';
import 'product_token.dart';

/// Códigos de falha que o PRÓPRIO cliente produz (não vêm da API).
abstract final class ClientFailureCodes {
  /// 2xx/3xx que não é o envelope `{ ok: true, … }` da casa (HTML do host
  /// errado, 302 de proxy, corpo torto) — F2B-ADV-04/ADV-12. Num ATO fiscal é
  /// desfecho DESCONHECIDO (a resposta não diz o que aconteceu).
  static const invalidResponse = 'CLIENT_INVALID_RESPONSE';

  /// A base da API não é uma URL utilizável (sem esquema/host) — erro de
  /// CONFIGURAÇÃO do build, nunca "rede caída" (F2B-ADV-10).
  static const configuration = 'CLIENT_CONFIGURATION';

  /// D-F148: a API que NÃO emitiu o token recusou a sessão, mas o EMISSOR (o
  /// setes-api) a aceita — a sessão fica; a tela diz que o serviço não a
  /// reconheceu (configuração de chave, institution divergente).
  static const sessionNotAccepted = 'SESSION_NOT_ACCEPTED';

  /// TODOS os códigos acima — a falha MONTADA pelo app (o `supportRef` dela, quando há, é texto do Dart, nunca referência do
  /// servidor). Gate socrático do delta da Rodada 11 (R11-SOC-04): quem precisa distinguir (a linha do lote — D-F180) lê ESTA lista, não
  /// um prefixo de texto; código novo aqui entra nela (cerca no teste do app).
  static const all = {invalidResponse, configuration, sessionNotAccepted};
}

/// As rotas de `/auth` que NÃO levam a sessão (o setes-api as serve sem o
/// `authMiddleware`): o 401 delas é de negócio. Qualquer outra `/auth/…` (a
/// `switch-institution`) leva o Bearer da sessão.
const _publicAuthPaths = {'/auth/login', '/auth/select-institution', '/auth/recovery-password', '/auth/change-password'};

/// O `data` OBJETO do envelope `{ ok: true, data: {…} }` — senão falha técnica
/// [ClientFailureCodes.invalidResponse] (F2B-ADV-04: `{}` virava "não
/// transmitida", "nada pendente" e "autorizada com chave vazia").
Map<String, dynamic> envelopeData(Map<String, dynamic> json) {
  final data = json['data'];
  if (json['ok'] != true || data is! Map<String, dynamic>) {
    throw const Failure(message: 'core.errors.invalidResponse', code: ClientFailureCodes.invalidResponse);
  }
  return data;
}

/// O envelope PAGINADO `{ ok: true, data: [...], page, pageSize, total }` —
/// senão falha técnica (nunca "lista vazia" calada — D-F130).
Map<String, dynamic> envelopePage(Map<String, dynamic> json) {
  if (json['ok'] != true || json['data'] is! List) {
    throw const Failure(message: 'core.errors.invalidResponse', code: ClientFailureCodes.invalidResponse);
  }
  return json;
}

/// Erro que NÃO é [Failure] na leitura de uma resposta (tipo trocado, campo
/// nulo) — vira falha técnica com mensagem do catálogo (F2B-ADV-12: o texto cru
/// do Dart ia para a tela); o texto técnico fica no `supportRef`.
Failure invalidResponseFailure(Object error) => Failure(
      message: 'core.errors.invalidResponse',
      code: ClientFailureCodes.invalidResponse,
      supportRef: error.toString(),
    );

/// Cliente HTTP de UMA API do produto: injeta o JWT e decodifica o envelope
/// `{ ok, data }`. O app NUNCA acessa o banco (decisão 1).
///
/// D-F138 (F2b, Valdo 2026-10-13): uma base, N instâncias — uma por base de
/// URL — e o token num [ProductToken] ÚNICO, lido a cada requisição. Os tipos
/// concretos são IRMÃOS ([ApiClient] = setes-api; [NfseApiClient] = nfse-api —
/// F2B-SOC-08/ADV-13): nenhum é subtipo do outro, então a injeção e o
/// compilador nunca entregam o cliente de uma API a quem pediu o da outra
/// (D-F4: nunca cruza). [token] continua sendo a porta de escrita/leitura
/// (atalho para o [ProductToken] — as escritas do login/guard/logout não mudam).
abstract class ProductApiClient {
  ProductApiClient({
    http.Client? client,
    required String baseUrl,
    ProductToken? session,
    required this.issuesSession,
    required this.strictEnvelope,
  })  : _client = client ?? http.Client(),
        baseUrl = _normalize(baseUrl),
        session = session ?? ProductToken();

  final http.Client _client;

  /// A base, sem barra final (F2B-ADV-10: `…/nfse/` + `/v1` virava `//v1`).
  final String baseUrl;

  /// O token do produto (compartilhado entre os clientes das N APIs).
  final ProductToken session;

  /// Esta API EMITE o token (o setes-api): o 401 dela com o token da sessão =
  /// a sessão morreu. As outras confirmam com o emissor antes (D-F148).
  final bool issuesSession;

  /// 2xx/3xx tem de ser o envelope `{ ok: true }` — senão é falha técnica
  /// ([ClientFailureCodes.invalidResponse]). A nfse-api responde SEMPRE assim;
  /// o setes-api tem rotas antigas fora do envelope (ficam toleradas).
  final bool strictEnvelope;

  static String _normalize(String base) {
    var b = base.trim();
    while (b.endsWith('/')) {
      b = b.substring(0, b.length - 1);
    }
    return b;
  }

  /// A base é uma URL absoluta http(s) com host (senão: erro de configuração).
  bool get _baseUsable {
    final u = Uri.tryParse(baseUrl);
    return u != null && (u.scheme == 'http' || u.scheme == 'https') && u.host.isNotEmpty;
  }

  String? get token => session.value;
  set token(String? value) => session.value = value;

  Future<Map<String, dynamic>> get(String path) async =>
      _send(path, (uri, h) => _client.get(uri, headers: h));

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? overrideToken,
  }) async =>
      _send(
        path,
        (uri, h) => _client.post(uri, headers: h, body: jsonEncode(body)),
        overrideToken: overrideToken,
      );

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async =>
      _send(path, (uri, h) => _client.put(uri, headers: h, body: jsonEncode(body)));

  Future<Map<String, dynamic>> delete(String path) async =>
      _send(path, (uri, h) => _client.delete(uri, headers: h));

  Future<Map<String, dynamic>> _send(
    String path,
    Future<http.Response> Function(Uri uri, Map<String, String> headers) run, {
    String? overrideToken,
  }) async {
    if (!_baseUsable) {
      throw Failure(
        message: 'core.errors.configuration',
        code: ClientFailureCodes.configuration,
        supportRef: baseUrl.isEmpty ? '(vazia)' : baseUrl,
      );
    }
    // o token da SESSÃO que esta requisição leva. O de seleção do login
    // (overrideToken) não é sessão, e as rotas PÚBLICAS de `/auth` (login,
    // seleção, recuperação e troca de senha — LISTA, nunca o prefixo: a
    // `/auth/switch-institution` exige a sessão — F2B-RG-04/SOCD-02) não a
    // levam: o 401 delas é de NEGÓCIO (senha errada), nunca expiração (F2B-ADV-16).
    final sessionToken = overrideToken == null && !_publicAuthPaths.contains(path) ? session.value : null;
    final bearer = overrideToken ?? sessionToken;
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (bearer != null) 'Authorization': 'Bearer $bearer',
    };
    late http.Response response;
    try {
      response = await run(Uri.parse('$baseUrl$path'), headers);
    } on FormatException catch (e) {
      throw Failure(message: 'core.errors.configuration', code: ClientFailureCodes.configuration, supportRef: e.message);
    } on ArgumentError catch (e) {
      throw Failure(message: 'core.errors.configuration', code: ClientFailureCodes.configuration, supportRef: '${e.message}');
    } catch (e) {
      throw NetworkFailure(detail: e.toString());
    }

    Map<String, dynamic>? json;
    try {
      final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
      json = decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      // corpo que não é o envelope da casa (proxy, página de erro) — nunca
      // derruba a tela com FormatException: vira falha técnica com o status
      json = null;
    }
    final body = json ?? <String, dynamic>{};

    // Contrato do Framework de Mensagens: `{ error, code?, ref?, fields[] }` —
    // code = catálogo de erros conhecidos (R8); ref = rastro do erro técnico
    // na tb_crashlytics central (R2). Mensagens default são CHAVES i18n
    // core.errors.* (a ponte de feedback traduz; chave inexistente passa
    // a própria string, então o PT do backend chega intacto).
    if (response.statusCode == 401) {
      final unauthorized = UnauthorizedFailure(
        message: _textOf(body['error']) ?? 'core.errors.unauthorized',
        code: _textOf(body['code']),
        supportRef: _textOf(body['ref']),
      );
      if (sessionToken == null) throw unauthorized;
      if (issuesSession) {
        session.expire(sessionToken);
        throw unauthorized;
      }
      // D-F148: quem não emitiu o token não decide sozinho que a sessão morreu
      if (await session.confirm(sessionToken) == SessionCheck.alive) {
        // o suporte vê o código e a frase de ORIGEM (kid desconhecido ×
        // institution divergente — F2B-SOCD-07), nunca só "não aceita"
        final origin = [_textOf(body['code']), _textOf(body['error']) ?? _textOf(body['ref'])].whereType<String>().where((s) => s.isNotEmpty).join(': ');
        throw Failure(
          message: 'core.errors.sessionNotAccepted',
          statusCode: 401,
          code: ClientFailureCodes.sessionNotAccepted,
          supportRef: origin.isEmpty ? null : origin,
        );
      }
      throw unauthorized;
    }
    if (response.statusCode >= 400) {
      throw Failure(
        message: _textOf(body['error']) ?? 'core.errors.generic',
        statusCode: response.statusCode,
        fields: (body['fields'] is List ? body['fields'] as List<dynamic> : const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(FailureField.fromJson)
            .toList(),
        code: _textOf(body['code']),
        supportRef: _textOf(body['ref']),
      );
    }
    if (strictEnvelope && (json == null || json['ok'] != true)) {
      throw Failure(
        message: 'core.errors.invalidResponse',
        statusCode: response.statusCode,
        code: ClientFailureCodes.invalidResponse,
      );
    }
    return body;
  }
}

/// Cliente do setes-api — o EMISSOR do token do produto (D-F13): o 401 dele com
/// o token da sessão = a sessão morreu. Rotas antigas fora do envelope seguem
/// toleradas.
class ApiClient extends ProductApiClient {
  ApiClient({
    super.client,
    super.baseUrl = AppConfig.baseApiUrl,
    super.session,
  }) : super(issuesSession: true, strictEnvelope: false);

  /// D-F148: o EMISSOR confirma a sessão (`GET /api/core/me`). 401 = morreu (a
  /// própria requisição já expira a sessão); qualquer outro erro não prova a
  /// morte (a sessão fica).
  Future<bool> sessionAlive() async {
    try {
      await get('/api/core/me');
      return true;
    } on UnauthorizedFailure {
      return false;
    } catch (_) {
      return true;
    }
  }
}

/// Cliente da nfse-api (D-F4/D-F138): o MESMO [ProductToken] do login (RS256
/// — a nfse-api só tem a chave pública) e a base `NFSE_API_URL` (D-F146 —
/// `--dart-define`; vazia/torta = configuração faltando, ver
/// [AppConfig.missingConfiguration]). Irmão do [ApiClient] (nunca subtipo):
/// datasource da nfse-api pede [NfseApiClient], nunca o do setes-api (D-F4).
/// Envelope ESTRITO (a nfse-api sempre responde `{ ok, data }`) e 401 só expira
/// a sessão depois de o emissor confirmar (D-F148).
class NfseApiClient extends ProductApiClient {
  NfseApiClient({
    super.client,
    super.baseUrl = AppConfig.nfseApiUrl,
    super.session,
  }) : super(issuesSession: false, strictEnvelope: true);
}

/// O campo de texto do envelope de erro — `null` se veio de outro tipo (o JSON
/// de erro de um gateway/WAF: `{"error": {...}}`): nunca TypeError (R5-ADV-09).
String? _textOf(Object? v) => v is String ? v : null;
