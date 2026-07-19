import 'package:core/core.dart';

import '../../domain/entity/settlement_entity.dart';

/// Datasource remoto da Baixa de Títulos: /api/settlements na setes-api
/// (módulo gêmeo — escopo por institution do JWT). Lookup de conta em
/// /api/bank-accounts (projeção local — módulo não importa módulo); a
/// opção Caixa (id 0) é oferecida pela TELA, fixa na frente da lista.
abstract class SettlementDatasource {
  /// Carteira de títulos por [status] 'open'|'settled', [kind] opcional
  /// ('RA'|'RM'|'PA'|'PM') e [filter] de entidade/nº do título.
  Future<List<SettlementBill>> bills(String status, String kind, String filter);

  /// Baixa em LOTE: N títulos → 1 settled_code → 1 movimento (N:1).
  Future<SettlementBatchResult> settle(SettlementBatchInput input);

  /// Baixas registradas (linha por EVENTO) para a aba Baixados.
  Future<List<SettlementSettled>> settled(String filter);

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
  Future<List<SettlementBill>> bills(
      String status, String kind, String filter) async {
    final params = <String>[
      'status=${Uri.encodeComponent(status)}',
      if (kind.isNotEmpty) 'kind=${Uri.encodeComponent(kind)}',
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
    ];
    final json =
        await client.get('/api/settlements/bills?${params.join('&')}');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => SettlementBill.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<SettlementBatchResult> settle(SettlementBatchInput input) async {
    final json = await client.post('/api/settlements', input.toJson());
    return SettlementBatchResult.fromJson(
        json['data'] as Map<String, dynamic>);
  }

  @override
  Future<List<SettlementSettled>> settled(String filter) async {
    final query =
        filter.isNotEmpty ? '?filter=${Uri.encodeComponent(filter)}' : '';
    final json = await client.get('/api/settlements/settled$query');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => SettlementSettled.fromJson(e as Map<String, dynamic>))
        .toList();
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
