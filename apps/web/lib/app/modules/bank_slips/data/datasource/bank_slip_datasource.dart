import 'package:core/core.dart';

import '../../domain/entity/bank_slip_entity.dart';

/// Datasource remoto dos Boletos: fala SÓ com /api/bank-slips na setes-api
/// (módulo gêmeo — escopo por institution do JWT). As listas de apoio da
/// emissão (carteiras e títulos abertos) vivem no datasource DEDICADO
/// [BankSlipLookupDatasource] (bank_slip_lookup_datasource.dart).
abstract class BankSlipDatasource {
  /// Página da lista por [status] 'open'|'settled'|'cancelled' ('' =
  /// todos) e [filter] (nosso número / nº do documento). Paginação D3:
  /// [pageSize] null deixa a API resolver a config page_size do usuário.
  Future<PagedResult<BankSlipListRow>> getList(String status, String filter,
      {int page = 1, int? pageSize});

  /// Detalhe: cabeçalho congelado + títulos + eventos.
  Future<BankSlipFull> getOne(int id);

  /// Emite (evento E) — 1 título ou N do mesmo cliente.
  Future<BankSlipIssueResult> issue(BankSlipIssueInput input);

  /// Liquida manualmente (evento L) — 409 BANK_SLIP_NOT_OPEN.
  Future<BankSlipSettleResult> settle(
      int id, double paidValue, String dtPayment);

  /// Cancela (evento C) — 409 BANK_SLIP_NOT_OPEN.
  Future<int> cancel(int id, String? note);

  /// Estorna a liquidação (evento X) — 409 BANK_SLIP_NOT_SETTLED.
  Future<BankSlipReverseResult> reverse(int id, String reason);
}

class BankSlipDatasourceImpl implements BankSlipDatasource {
  const BankSlipDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<PagedResult<BankSlipListRow>> getList(String status, String filter,
      {int page = 1, int? pageSize}) async {
    final params = <String>[
      if (status.isNotEmpty) 'status=${Uri.encodeComponent(status)}',
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'page=$page',
      if (pageSize != null) 'pageSize=$pageSize',
    ];
    final json = await client.get('/api/bank-slips?${params.join('&')}');
    return PagedResult.fromJson(json, BankSlipListRow.fromJson);
  }

  @override
  Future<BankSlipFull> getOne(int id) async {
    final json = await client.get('/api/bank-slips/$id');
    return BankSlipFull.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<BankSlipIssueResult> issue(BankSlipIssueInput input) async {
    final json = await client.post('/api/bank-slips', input.toJson());
    return BankSlipIssueResult.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<BankSlipSettleResult> settle(
      int id, double paidValue, String dtPayment) async {
    final json = await client.post('/api/bank-slips/$id/settle', {
      'paidValue': paidValue,
      'dtPayment': dtPayment,
    });
    return BankSlipSettleResult.fromJson(
        json['data'] as Map<String, dynamic>);
  }

  @override
  Future<int> cancel(int id, String? note) async {
    final json = await client.post('/api/bank-slips/$id/cancel', {
      'note': (note == null || note.trim().isEmpty) ? null : note.trim(),
    });
    final data = json['data'] as Map<String, dynamic>? ?? const {};
    return jsonInt(data['event']) ?? 0;
  }

  @override
  Future<BankSlipReverseResult> reverse(int id, String reason) async {
    final json = await client.post('/api/bank-slips/$id/reverse', {
      'reason': reason,
    });
    return BankSlipReverseResult.fromJson(
        json['data'] as Map<String, dynamic>);
  }
}
