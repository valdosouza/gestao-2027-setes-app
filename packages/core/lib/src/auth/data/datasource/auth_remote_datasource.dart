import '../../../shared/http/api_client.dart';
import '../../domain/entity/session_user.dart';
import '../model/login_result_model.dart';

/// data implementa o que domain define (decisão 12).
class AuthRemoteDatasource {
  const AuthRemoteDatasource({required this.client});

  final ApiClient client;

  Future<LoginResultModel> login(String email, String password) async {
    final json = envelopeOk(await client.post('/auth/login', {
      'email': email,
      'password': password,
    }), service: 'setes-api');
    final result = LoginResultModel.fromJson(json);
    // LD-ADV-01 (gate adversarial do último delta, MEDIUM — a regra da D-F210): um 200 sem token E sem token de seleção (página de proxy,
    // `{ok:true}`) não é login — antes passava como sucesso com token nulo e o AuthBloc girava para sempre (`session.token!`)
    // LE-ADV-01/LE-ADV-03 (gate do delta 60df1df..5f6d3be — a mesma regra): token VAZIO conta como ausente (o ProductToken grava "" como
    // nulo e a guarda voltava ao login mudo), e a seleção sem NENHUM estabelecimento não é seleção (a tela abria vazia, sem saída)
    final hasToken = (result.token ?? '').isNotEmpty;
    final hasSelection = (result.selectionToken ?? '').isNotEmpty;
    if (!hasToken && !hasSelection) {
      throw invalidResponseFailure('login sem token nem selectionToken', service: 'setes-api');
    }
    if (!hasToken && result.institutions.isEmpty) {
      throw invalidResponseFailure('seleção de estabelecimento sem estabelecimentos', service: 'setes-api');
    }
    return result;
  }

  Future<String> selectInstitution(String selectionToken, int institutionId) async {
    final json = envelopeOk(await client.post(
      '/auth/select-institution',
      {'institutionId': institutionId},
      overrideToken: selectionToken,
    ), service: 'setes-api');
    return json['token'] as String;
  }

  /// Identificação do usuário logado (UserBadge da home).
  Future<SessionUser> getMe() async {
    final json = envelopeOk(await client.get('/api/core/me'), service: 'setes-api');
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return SessionUser(
      userId: (data['userId'] as num?)?.toInt() ?? 0,
      name: data['name'] as String? ?? '',
      role: data['role'] as String? ?? '',
      institutionId: (data['institutionId'] as num?)?.toInt() ?? 0,
      institutionName: data['institutionName'] as String?,
      context: data['context'] as Map<String, dynamic>?,
    );
  }

  /// Fluxo weberpsetes: gera código de recuperação (enviado por e-mail).
  Future<void> recoveryPassword(String email) async {
    envelopeOk(await client.post('/auth/recovery-password', {'email': email}), service: 'setes-api');
  }

  /// Troca a senha com o código recebido. Senha em texto puro por HTTPS —
  /// o hash é aplicado NO BACKEND (decisão 2 da Fase 2).
  ///
  /// CONHECIMENTO NEGATIVO (D-F218 = Q-LE1 (a), Valdo 2026-10-14): a troca NÃO é idempotente — o servidor consome o código
  /// (`activation_key = NULL`). Se a senha foi trocada e a resposta chegou ilegível (ou a rede caiu na volta), a nova tentativa dá
  /// "Código inválido" com a senha JÁ trocada; a saída do operador é entrar com a senha nova ou pedir outro código. Idem a recuperação
  /// (um 2º pedido gera código novo e invalida o do 1º e-mail).
  Future<void> changePassword(String email, String code, String newPassword) async {
    envelopeOk(await client.post('/auth/change-password', {
      'email': email,
      'code': code,
      'newPassword': newPassword,
    }), service: 'setes-api');
  }
}
