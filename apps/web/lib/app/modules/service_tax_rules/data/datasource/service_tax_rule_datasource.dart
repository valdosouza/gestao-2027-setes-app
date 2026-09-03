import 'package:core/core.dart';

import '../../domain/entity/service_tax_rule_entity.dart';

/// Datasource remoto de Regras de Tributação de Serviço:
/// /api/service-tax-rules na setes-api (módulo gêmeo — escopo por
/// institution vem do JWT). O lookup dos itens da Lista de Serviços vive em
/// ServiceTaxRuleLookupDatasource (o que a page consome direto).
abstract class ServiceTaxRuleDatasource {
  /// Página da lista (filtro REMOTO por cidade/item/descrição): [pageSize]
  /// null deixa a API resolver a config page_size do usuário.
  Future<PagedResult<ServiceTaxRuleEntity>> getList(String filter,
      {int page = 1, int? pageSize});

  /// Regra por id para edição.
  Future<ServiceTaxRuleEntity> getById(int id);

  /// Cria a regra — devolve o id (MAX+1 da API).
  Future<int> post(ServiceTaxRuleInput input);

  /// Atualiza a regra.
  Future<void> put(int id, ServiceTaxRuleInput input);

  /// Soft delete (409 SERVICE_TAX_RULE_IN_USE quando um serviço a aponta).
  Future<void> delete(int id);
}

class ServiceTaxRuleDatasourceImpl implements ServiceTaxRuleDatasource {
  const ServiceTaxRuleDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<PagedResult<ServiceTaxRuleEntity>> getList(String filter,
      {int page = 1, int? pageSize}) async {
    final params = [
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'page=$page',
      if (pageSize != null) 'pageSize=$pageSize',
    ];
    final json =
        await client.get('/api/service-tax-rules?${params.join('&')}');
    return PagedResult.fromJson(json, ServiceTaxRuleEntity.fromJson);
  }

  @override
  Future<ServiceTaxRuleEntity> getById(int id) async {
    final json = await client.get('/api/service-tax-rules/$id');
    return ServiceTaxRuleEntity.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<int> post(ServiceTaxRuleInput input) async {
    final json = await client.post('/api/service-tax-rules', input.toJson());
    final data = json['data'] as Map<String, dynamic>? ?? const {};
    return jsonInt(data['id']) ?? 0;
  }

  @override
  Future<void> put(int id, ServiceTaxRuleInput input) async {
    await client.put('/api/service-tax-rules/$id', input.toJson());
  }

  @override
  Future<void> delete(int id) async {
    await client.delete('/api/service-tax-rules/$id');
  }
}
