import 'package:core/core.dart';

import '../../domain/entity/check_entity.dart';

/// Datasource remoto dos Cheques: fala SÓ com /api/checks na setes-api
/// (módulo gêmeo — escopo por institution do JWT). As listas de apoio das
/// ações (contas/factoring/títulos a pagar) vivem no datasource DEDICADO
/// [CheckLookupDatasource] (check_lookup_datasource.dart).
abstract class CheckDatasource {
  /// Página da lista por [status] derivado ('' = todos) e [filter] (nº do
  /// cheque ou emitente). [pageSize] null deixa a API resolver a config
  /// page_size do usuário.
  Future<PagedResult<CheckListRow>> getList(String status, String filter,
      {int page = 1, int? pageSize});

  /// Detalhe: cabeçalho imutável + história completa de eventos.
  Future<CheckFull> getOne(int id);

  /// Deposita (evento B).
  Future<CheckSettledResult> deposit(
      int id, String dtRecord, int bankAccountId);

  /// Desconta na factoring (evento D).
  Future<CheckSettledResult> discount(int id, String dtRecord,
      int factoringEntityId, int bankAccountId, double feeValue);

  /// Retorno com reembolso (evento T).
  Future<CheckSettledResult> returnRefund(
      int id, String dtRecord, int bankAccountId);

  /// Retorno bom (evento F) — devolve o nº do evento gerado.
  Future<int> returnGood(int id, String? note);

  /// Usa em pagamento (evento P).
  Future<CheckSettledResult> pay(
      int id, String dtRecord, int orderId, int parcel);

  /// Devolve (evento V) — cria título novo contra a origem.
  Future<CheckReturnResult> returnToOrigin(
      int id, String dtRecord, String? note);

  /// Estorna o último evento (evento X).
  Future<CheckReverseResult> reverse(int id, int event, String reason);
}

class CheckDatasourceImpl implements CheckDatasource {
  const CheckDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<PagedResult<CheckListRow>> getList(String status, String filter,
      {int page = 1, int? pageSize}) async {
    final params = <String>[
      if (status.isNotEmpty) 'status=${Uri.encodeComponent(status)}',
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'page=$page',
      if (pageSize != null) 'pageSize=$pageSize',
    ];
    final json = await client.get('/api/checks?${params.join('&')}');
    return PagedResult.fromJson(json, CheckListRow.fromJson);
  }

  @override
  Future<CheckFull> getOne(int id) async {
    final json = await client.get('/api/checks/$id');
    return CheckFull.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<CheckSettledResult> deposit(
      int id, String dtRecord, int bankAccountId) async {
    final json = await client.post('/api/checks/$id/deposit', {
      'dtRecord': dtRecord,
      'bankAccountId': bankAccountId,
    });
    return CheckSettledResult.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<CheckSettledResult> discount(int id, String dtRecord,
      int factoringEntityId, int bankAccountId, double feeValue) async {
    final json = await client.post('/api/checks/$id/discount', {
      'dtRecord': dtRecord,
      'factoringEntityId': factoringEntityId,
      'bankAccountId': bankAccountId,
      'feeValue': feeValue,
    });
    return CheckSettledResult.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<CheckSettledResult> returnRefund(
      int id, String dtRecord, int bankAccountId) async {
    final json = await client.post('/api/checks/$id/return-refund', {
      'dtRecord': dtRecord,
      'bankAccountId': bankAccountId,
    });
    return CheckSettledResult.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<int> returnGood(int id, String? note) async {
    final json = await client.post('/api/checks/$id/return-good', {
      'note': (note == null || note.trim().isEmpty) ? null : note.trim(),
    });
    final data = json['data'] as Map<String, dynamic>? ?? const {};
    return jsonInt(data['event']) ?? 0;
  }

  @override
  Future<CheckSettledResult> pay(
      int id, String dtRecord, int orderId, int parcel) async {
    final json = await client.post('/api/checks/$id/pay', {
      'dtRecord': dtRecord,
      'orderId': orderId,
      'parcel': parcel,
    });
    return CheckSettledResult.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<CheckReturnResult> returnToOrigin(
      int id, String dtRecord, String? note) async {
    final json = await client.post('/api/checks/$id/return', {
      'dtRecord': dtRecord,
      'note': (note == null || note.trim().isEmpty) ? null : note.trim(),
    });
    return CheckReturnResult.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<CheckReverseResult> reverse(
      int id, int event, String reason) async {
    final json = await client.post('/api/checks/$id/reverse', {
      'event': event,
      'reason': reason,
    });
    return CheckReverseResult.fromJson(json['data'] as Map<String, dynamic>);
  }
}
