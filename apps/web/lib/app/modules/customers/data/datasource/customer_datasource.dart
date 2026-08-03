import 'package:core/core.dart';

import '../../domain/entity/object_customer.dart';

/// Datasource remoto de Cliente: /api/customers na setes-api (módulo gêmeo,
/// SEM superGuard — cadastro do cliente; escopo por institution vem do JWT).
///
/// Fase 3 Entidade Única: o POST devolve { id, reused } — reused=true quando
/// a API reaproveitou uma entity existente pelo CPF/CNPJ (decisões 1 e 9).
abstract class CustomerDatasource {
  /// Página da lista (paginação D3): [pageSize] null deixa a API resolver a
  /// config page_size do usuário (D4).
  Future<PagedResult<CustomerListItem>> getList(String filter,
      {int page = 1, int? pageSize});

  /// Objeto COMPLETO (entity + fiscal + 3 listas + customer).
  Future<ObjectCustomer> get(int id);
  Future<CustomerPostResult> post(ObjectCustomer customer);
  Future<void> put(ObjectCustomer customer);
  Future<void> delete(int id);
}

class CustomerDatasourceImpl implements CustomerDatasource {
  const CustomerDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<PagedResult<CustomerListItem>> getList(String filter,
      {int page = 1, int? pageSize}) async {
    final params = [
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'page=$page',
      if (pageSize != null) 'pageSize=$pageSize',
    ];
    final json = await client.get('/api/customers?${params.join('&')}');
    return PagedResult.fromJson(json, CustomerListItem.fromJson);
  }

  @override
  Future<ObjectCustomer> get(int id) async {
    final json = await client.get('/api/customers/$id');
    return ObjectCustomer.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<CustomerPostResult> post(ObjectCustomer customer) async {
    final json = await client.post('/api/customers', customer.toJson());
    final data = json['data'] as Map<String, dynamic>? ?? const {};
    return CustomerPostResult(
      id:     (data['id'] as num).toInt(),
      reused: data['reused'] as bool? ?? false,
    );
  }

  @override
  Future<void> put(ObjectCustomer customer) async {
    await client.put('/api/customers/${customer.id}', customer.toJson());
  }

  @override
  Future<void> delete(int id) async {
    await client.delete('/api/customers/$id');
  }
}
