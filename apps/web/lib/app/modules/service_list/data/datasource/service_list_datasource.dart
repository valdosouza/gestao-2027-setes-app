import 'package:core/core.dart';

import '../../domain/entity/service_list_entity.dart';

/// Datasource remoto da Lista de Serviços: /api/service-list na setes-api.
/// Acesso exclusivo para role='super' (guard isSuper() no backend).
abstract class ServiceListDatasource {
  /// Página da lista (paginação D3): [pageSize] null deixa a API resolver a
  /// config page_size do usuário (D4).
  Future<PagedResult<ServiceListEntity>> getList(String filter,
      {int page = 1, int? pageSize});
  Future<void> post(ServiceListEntity item);
  Future<void> put(ServiceListEntity item);
  Future<void> delete(String id);
}

class ServiceListDatasourceImpl implements ServiceListDatasource {
  const ServiceListDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<PagedResult<ServiceListEntity>> getList(String filter,
      {int page = 1, int? pageSize}) async {
    final params = [
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'page=$page',
      if (pageSize != null) 'pageSize=$pageSize',
    ];
    final json = await client.get('/api/service-list?${params.join('&')}');
    return PagedResult.fromJson(json, ServiceListEntity.fromJson);
  }

  /// O item é digitado pelo usuário (409 com fields[id] se já existir).
  @override
  Future<void> post(ServiceListEntity item) async {
    await client.post('/api/service-list', item.toCreateJson());
  }

  @override
  Future<void> put(ServiceListEntity item) async {
    await client.put('/api/service-list/${item.id}', item.toJson());
  }

  @override
  Future<void> delete(String id) async {
    await client.delete('/api/service-list/$id');
  }
}
