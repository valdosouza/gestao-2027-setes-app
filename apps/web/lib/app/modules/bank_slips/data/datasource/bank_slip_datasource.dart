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
      {int page = 1, int? pageSize, bool pendingOnly = false});

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

  /// Onda 2 — registro no banco, consulta, PDF oficial e consulta ativa.
  Future<BankSlipRegisterResult> register(int id);
  Future<BankSlipRefreshResult> refresh(int id);
  Future<String> pdf(int id);
  Future<BankSlipBankSyncReport> bankSync();

  /// D-I25: reaplica o efeito de uma voz R/C/V recusada (POST /:id/reapply).
  Future<BankSlipReapplyResult> reapply(int id, int attempt, int event);
}

class BankSlipDatasourceImpl implements BankSlipDatasource {
  const BankSlipDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<PagedResult<BankSlipListRow>> getList(String status, String filter,
      {int page = 1, int? pageSize, bool pendingOnly = false}) async {
    final params = <String>[
      if (status.isNotEmpty) 'status=${Uri.encodeComponent(status)}',
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      if (pendingOnly) 'pending=true',
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

  @override
  Future<BankSlipRegisterResult> register(int id) async {
    final json = await client.post('/api/bank-slips/$id/register', const {});
    return BankSlipRegisterResult.fromJson(json['data'] as Map<String, dynamic>? ?? const {});
  }

  @override
  Future<BankSlipRefreshResult> refresh(int id) async {
    final json = await client.post('/api/bank-slips/$id/refresh', const {});
    return BankSlipRefreshResult.fromJson(json['data'] as Map<String, dynamic>? ?? const {});
  }

  @override
  Future<String> pdf(int id) async {
    final json = await client.get('/api/bank-slips/$id/pdf');
    return (json['data'] as Map<String, dynamic>? ?? const {})['pdfBase64']?.toString() ?? '';
  }

  @override
  Future<BankSlipReapplyResult> reapply(int id, int attempt, int event) async {
    final json = await client.post(
        '/api/bank-slips/$id/reapply', {'attempt': attempt, 'event': event});
    return BankSlipReapplyResult.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<BankSlipBankSyncReport> bankSync() async {
    final json = await client.post('/api/bank-slips/refresh', const {});
    return BankSlipBankSyncReport.fromJson(json['data'] as Map<String, dynamic>? ?? const {});
  }
}
