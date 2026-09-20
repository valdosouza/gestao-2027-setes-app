import 'package:core/core.dart';

import '../../domain/entity/bank_account_channel_entity.dart';

/// Datasource DEDICADO do sub-recurso Canal API da conta
/// (/api/bank-accounts/:id/channel — Onda 2). Consumido pela seção autônoma
/// do form (mesmo padrão da Chave de Sincronização do Institution): a seção
/// carrega/salva por aqui e fala com a ponte de feedback; o bloc da conta
/// não entra, porque o canal é um sub-recurso com ciclo próprio.
abstract class BankAccountChannelDatasource {
  Future<BankAccountChannelView> get(int bankAccountId);
  Future<BankAccountChannelView> save(int bankAccountId,
      {required String environment, String? clientId, required String active});
  Future<void> remove(int bankAccountId);
  Future<BankAccountChannelView> rotateToken(int bankAccountId);

  /// WRITE-ONLY (D-I3): cada campo é opcional; o que vier é gravado no cofre.
  Future<BankAccountChannelView> saveSecrets(int bankAccountId,
      {String? certificatePem, String? privateKeyPem, String? clientSecret});
  Future<BankAccountChannelView> clearSecrets(int bankAccountId);

  /// Prova de vida: token + mTLS no banco (não escreve nada).
  Future<ChannelTestResult> test(int bankAccountId);
}

class BankAccountChannelDatasourceImpl implements BankAccountChannelDatasource {
  const BankAccountChannelDatasourceImpl({required this.client});

  final ApiClient client;

  BankAccountChannelView _view(Map<String, dynamic> json) =>
      BankAccountChannelView.fromJson(json['data'] as Map<String, dynamic>? ?? const {});

  @override
  Future<BankAccountChannelView> get(int bankAccountId) async =>
      _view(await client.get('/api/bank-accounts/$bankAccountId/channel'));

  @override
  Future<BankAccountChannelView> save(int bankAccountId,
      {required String environment, String? clientId, required String active}) async =>
      _view(await client.put('/api/bank-accounts/$bankAccountId/channel', {
        'environment': environment,
        'clientId': (clientId == null || clientId.trim().isEmpty) ? null : clientId.trim(),
        'active': active,
      }));

  @override
  Future<void> remove(int bankAccountId) async {
    await client.delete('/api/bank-accounts/$bankAccountId/channel');
  }

  @override
  Future<BankAccountChannelView> rotateToken(int bankAccountId) async =>
      _view(await client.post('/api/bank-accounts/$bankAccountId/channel/rotate-token', const {}));

  @override
  Future<BankAccountChannelView> saveSecrets(int bankAccountId,
      {String? certificatePem, String? privateKeyPem, String? clientSecret}) async =>
      _view(await client.put('/api/bank-accounts/$bankAccountId/channel/secrets', {
        if (certificatePem != null && certificatePem.trim().isNotEmpty) 'certificatePem': certificatePem.trim(),
        if (privateKeyPem != null && privateKeyPem.trim().isNotEmpty) 'privateKeyPem': privateKeyPem.trim(),
        if (clientSecret != null && clientSecret.trim().isNotEmpty) 'clientSecret': clientSecret.trim(),
      }));

  @override
  Future<BankAccountChannelView> clearSecrets(int bankAccountId) async =>
      _view(await client.delete('/api/bank-accounts/$bankAccountId/channel/secrets'));

  @override
  Future<ChannelTestResult> test(int bankAccountId) async {
    final json = await client.post('/api/bank-accounts/$bankAccountId/channel/test', const {});
    return ChannelTestResult.fromJson(json['data'] as Map<String, dynamic>? ?? const {});
  }
}
