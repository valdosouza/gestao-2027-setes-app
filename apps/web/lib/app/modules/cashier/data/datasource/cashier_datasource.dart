import 'package:core/core.dart';

import '../../domain/entity/cashier_entity.dart';

/// Datasource remoto do Caixa: /api/cashier na setes-api (módulo gêmeo —
/// escopo por institution+usuário do JWT). Lookup de conta bancária em
/// /api/bank-accounts (projeção local — módulo nunca importa módulo,
/// mesmo padrão de settlements/orders).
abstract class CashierDatasource {
  /// Sessão ABERTA do usuário corrente, ou null (nenhuma aberta hoje).
  Future<CashierRow?> current();

  /// Abre a sessão (dia+usuário+terminal 0) — 409 se já existir aberta.
  Future<CashierRow> open();

  /// Saldo derivado + registrado por forma de pagamento.
  Future<CashierDetail> detail(int id);

  /// Retirada simples ou transferência (com [destinationBankAccountId]).
  Future<CashierWithdrawResult> withdraw(int id, CashierWithdrawInput input);

  /// Fechamento — conferência por forma + transferência opcional do saldo.
  Future<CashierCloseResult> close(int id, CashierCloseInput input);

  /// Contas bancárias da institution para o lookup de destino (opcional).
  Future<List<CashierBankAccountLookup>> bankAccounts(String filter);
}

class CashierDatasourceImpl implements CashierDatasource {
  const CashierDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<CashierRow?> current() async {
    final json = await client.get('/api/cashier/current');
    final data = json['data'] as Map<String, dynamic>?;
    return data == null ? null : CashierRow.fromJson(data);
  }

  @override
  Future<CashierRow> open() async {
    final json = await client.post('/api/cashier/open', const {});
    return CashierRow.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<CashierDetail> detail(int id) async {
    final json = await client.get('/api/cashier/$id');
    return CashierDetail.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<CashierWithdrawResult> withdraw(
      int id, CashierWithdrawInput input) async {
    final json =
        await client.post('/api/cashier/$id/withdraw', input.toJson());
    return CashierWithdrawResult.fromJson(
        json['data'] as Map<String, dynamic>);
  }

  @override
  Future<CashierCloseResult> close(int id, CashierCloseInput input) async {
    final json = await client.post('/api/cashier/$id/close', input.toJson());
    return CashierCloseResult.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<List<CashierBankAccountLookup>> bankAccounts(String filter) async {
    final params = <String>[
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'pageSize=100',
    ];
    final json = await client.get('/api/bank-accounts?${params.join('&')}');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) =>
            CashierBankAccountLookup.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
