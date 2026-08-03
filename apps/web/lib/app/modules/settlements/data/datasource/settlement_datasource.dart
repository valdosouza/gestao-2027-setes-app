import 'package:core/core.dart';

import '../../domain/entity/settlement_entity.dart';

/// Datasource remoto da Baixa de Títulos: /api/settlements na setes-api
/// (módulo gêmeo — escopo por institution do JWT). Lookup de conta em
/// /api/bank-accounts (projeção local — módulo não importa módulo); a
/// opção Caixa (id 0) é oferecida pela TELA, fixa na frente da lista.
abstract class SettlementDatasource {
  /// Página da carteira de títulos por [status] 'open'|'settled', [kind]
  /// opcional ('RA'|'RM'|'PA'|'PM') e [filter] de entidade/nº do título.
  /// Paginação D3: [pageSize] null deixa a API resolver a config
  /// page_size do usuário (D4).
  Future<PagedResult<SettlementBill>> bills(
      String status, String kind, String filter,
      {int page = 1, int? pageSize});

  /// Baixa em LOTE: N títulos → 1 settled_code → 1 movimento (N:1).
  Future<SettlementBatchResult> settle(SettlementBatchInput input);

  /// Página das baixas registradas (linha por EVENTO) — aba Baixados.
  Future<PagedResult<SettlementSettled>> settled(String filter,
      {int page = 1, int? pageSize});

  /// Estorno IMUTÁVEL (lançamento inverso) — 409 = baixa não vigente.
  Future<SettlementReversalResult> reversal(
      int orderId, int parcel, int event, String reason);

  /// Extrato banco/caixa do filtro — totais e saldo VÊM da API.
  Future<SettlementStatementReport> statements(
      int bankAccountId, String? dtFrom, String? dtTo);

  /// Contas bancárias da institution para o lookup (Caixa 0 é da tela).
  Future<List<SettlementBankAccountLookup>> bankAccounts();
}

class SettlementDatasourceImpl implements SettlementDatasource {
  const SettlementDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<PagedResult<SettlementBill>> bills(
      String status, String kind, String filter,
      {int page = 1, int? pageSize}) async {
    final params = <String>[
      'status=${Uri.encodeComponent(status)}',
      if (kind.isNotEmpty) 'kind=${Uri.encodeComponent(kind)}',
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'page=$page',
      if (pageSize != null) 'pageSize=$pageSize',
    ];
    final json =
        await client.get('/api/settlements/bills?${params.join('&')}');
    return PagedResult.fromJson(json, SettlementBill.fromJson);
  }

  @override
  Future<SettlementBatchResult> settle(SettlementBatchInput input) async {
    final json = await client.post('/api/settlements', input.toJson());
    return SettlementBatchResult.fromJson(
        json['data'] as Map<String, dynamic>);
  }

  @override
  Future<PagedResult<SettlementSettled>> settled(String filter,
      {int page = 1, int? pageSize}) async {
    final params = <String>[
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'page=$page',
      if (pageSize != null) 'pageSize=$pageSize',
    ];
    final json =
        await client.get('/api/settlements/settled?${params.join('&')}');
    return PagedResult.fromJson(json, SettlementSettled.fromJson);
  }

  @override
  Future<SettlementReversalResult> reversal(
      int orderId, int parcel, int event, String reason) async {
    final json = await client.post('/api/settlements/reversal', {
      'orderId': orderId,
      'parcel':  parcel,
      'event':   event,
      'reason':  reason,
    });
    return SettlementReversalResult.fromJson(
        json['data'] as Map<String, dynamic>);
  }

  @override
  Future<SettlementStatementReport> statements(
      int bankAccountId, String? dtFrom, String? dtTo) async {
    final params = <String>[
      'bankAccountId=$bankAccountId',
      if (dtFrom != null && dtFrom.isNotEmpty)
        'dtFrom=${Uri.encodeComponent(dtFrom)}',
      if (dtTo != null && dtTo.isNotEmpty)
        'dtTo=${Uri.encodeComponent(dtTo)}',
    ];
    final json =
        await client.get('/api/settlements/statements?${params.join('&')}');
    return SettlementStatementReport.fromJson(
        json['data'] as Map<String, dynamic>);
  }

  @override
  Future<List<SettlementBankAccountLookup>> bankAccounts() async {
    final json = await client.get('/api/bank-accounts');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) =>
            SettlementBankAccountLookup.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
