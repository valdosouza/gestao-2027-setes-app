import 'package:core/core.dart';

import '../../domain/entity/object_provider.dart';

/// Datasource remoto de Fornecedor: /api/providers na setes-api (módulo
/// gêmeo — cadastro do cliente; escopo por institution vem do JWT). POST
/// devolve { id, reused } — reused=true quando a API reaproveitou uma
/// entity existente pelo CPF/CNPJ (decisões 1 e 9 da Fase 3).
abstract class ProviderDatasource {
  /// Página da lista (paginação D3): [pageSize] null deixa a API resolver a
  /// config page_size do usuário (D4).
  Future<PagedResult<ProviderListItem>> getList(String filter,
      {int page = 1, int? pageSize});

  /// Objeto COMPLETO (entity + fiscal + 3 listas + provider + tax).
  Future<ObjectProvider> get(int id);
  Future<ProviderPostResult> post(ObjectProvider provider);
  Future<void> put(ObjectProvider provider);
  Future<void> delete(int id);
}

class ProviderDatasourceImpl implements ProviderDatasource {
  const ProviderDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<PagedResult<ProviderListItem>> getList(String filter,
      {int page = 1, int? pageSize}) async {
    final params = [
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'page=$page',
      if (pageSize != null) 'pageSize=$pageSize',
    ];
    final json = await client.get('/api/providers?${params.join('&')}');
    return PagedResult.fromJson(json, ProviderListItem.fromJson);
  }

  @override
  Future<ObjectProvider> get(int id) async {
    final json = await client.get('/api/providers/$id');
    return ObjectProvider.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<ProviderPostResult> post(ObjectProvider provider) async {
    final json = await client.post('/api/providers', provider.toJson());
    final data = json['data'] as Map<String, dynamic>? ?? const {};
    return ProviderPostResult(
      id:     (data['id'] as num).toInt(),
      reused: data['reused'] as bool? ?? false,
    );
  }

  @override
  Future<void> put(ObjectProvider provider) async {
    await client.put('/api/providers/${provider.id}', provider.toJson());
  }

  @override
  Future<void> delete(int id) async {
    await client.delete('/api/providers/$id');
  }
}
