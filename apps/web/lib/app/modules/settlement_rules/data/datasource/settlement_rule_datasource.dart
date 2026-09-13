import 'package:core/core.dart';

import '../../domain/entity/settlement_rule_entity.dart';

/// Datasource remoto de Regras de Recebimento: /api/settlement-rules na
/// setes-api (módulo gêmeo; escopo por institution vem do JWT). Os lookups
/// do form vivem em datasource DEDICADO ([SettlementRuleLookupDatasource])
/// — a page só toca lookup.
abstract class SettlementRuleDatasource {
  /// Página da lista (filtro REMOTO por forma/conta): [pageSize] null deixa
  /// a API resolver a config page_size do usuário.
  Future<PagedResult<SettlementRuleListItem>> getList(String filter,
      {int page = 1, int? pageSize});

  /// Contrato completo (+ note) para edição.
  Future<SettlementRuleFull> getById(int id);

  /// Cria o contrato — devolve o id (= paymentTypeId).
  Future<int> post(SettlementRuleInput input);

  /// Atualiza o contrato (a forma não muda — é a PK).
  Future<void> put(int id, SettlementRuleInput input);

  /// Soft delete — a forma volta a "sem baixa automática".
  Future<void> delete(int id);
}

class SettlementRuleDatasourceImpl implements SettlementRuleDatasource {
  const SettlementRuleDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<PagedResult<SettlementRuleListItem>> getList(String filter,
      {int page = 1, int? pageSize}) async {
    final params = [
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'page=$page',
      if (pageSize != null) 'pageSize=$pageSize',
    ];
    final json =
        await client.get('/api/settlement-rules?${params.join('&')}');
    return PagedResult.fromJson(json, SettlementRuleListItem.fromJson);
  }

  @override
  Future<SettlementRuleFull> getById(int id) async {
    final json = await client.get('/api/settlement-rules/$id');
    return SettlementRuleFull.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<int> post(SettlementRuleInput input) async {
    final json = await client.post('/api/settlement-rules', input.toJson());
    final data = json['data'] as Map<String, dynamic>? ?? const {};
    return jsonInt(data['id']) ?? 0;
  }

  @override
  Future<void> put(int id, SettlementRuleInput input) async {
    await client.put('/api/settlement-rules/$id', input.toUpdateJson());
  }

  @override
  Future<void> delete(int id) async {
    await client.delete('/api/settlement-rules/$id');
  }
}
