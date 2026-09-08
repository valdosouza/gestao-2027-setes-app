import 'package:core/core.dart';

import '../../domain/entity/financial_contract_entity.dart';

/// Datasource remoto de Contratos Financeiros: /api/financial-contracts na
/// setes-api (módulo gêmeo; escopo por institution vem do JWT). Os lookups
/// do form vivem em datasource DEDICADO ([FinancialContractLookupDatasource])
/// — a page só toca lookup.
abstract class FinancialContractDatasource {
  /// Página da lista (filtro REMOTO por forma/conta): [pageSize] null deixa
  /// a API resolver a config page_size do usuário.
  Future<PagedResult<FinancialContractListItem>> getList(String filter,
      {int page = 1, int? pageSize});

  /// Contrato completo (+ note) para edição.
  Future<FinancialContractFull> getById(int id);

  /// Cria o contrato — devolve o id (= paymentTypeId).
  Future<int> post(FinancialContractInput input);

  /// Atualiza o contrato (a forma não muda — é a PK).
  Future<void> put(int id, FinancialContractInput input);

  /// Soft delete — a forma volta a "sem baixa automática".
  Future<void> delete(int id);
}

class FinancialContractDatasourceImpl implements FinancialContractDatasource {
  const FinancialContractDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<PagedResult<FinancialContractListItem>> getList(String filter,
      {int page = 1, int? pageSize}) async {
    final params = [
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'page=$page',
      if (pageSize != null) 'pageSize=$pageSize',
    ];
    final json =
        await client.get('/api/financial-contracts?${params.join('&')}');
    return PagedResult.fromJson(json, FinancialContractListItem.fromJson);
  }

  @override
  Future<FinancialContractFull> getById(int id) async {
    final json = await client.get('/api/financial-contracts/$id');
    return FinancialContractFull.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<int> post(FinancialContractInput input) async {
    final json = await client.post('/api/financial-contracts', input.toJson());
    final data = json['data'] as Map<String, dynamic>? ?? const {};
    return jsonInt(data['id']) ?? 0;
  }

  @override
  Future<void> put(int id, FinancialContractInput input) async {
    await client.put('/api/financial-contracts/$id', input.toUpdateJson());
  }

  @override
  Future<void> delete(int id) async {
    await client.delete('/api/financial-contracts/$id');
  }
}
