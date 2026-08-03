import 'package:core/core.dart';

import '../../domain/entity/cfop_entity.dart';

/// Datasource remoto de CFOP: /api/cfop na setes-api.
/// Acesso exclusivo para role='super' (guard isSuper() no backend).
abstract class CfopDatasource {
  /// Página da lista (paginação D3): [pageSize] null deixa a API resolver a
  /// config page_size do usuário (D4).
  Future<PagedResult<CfopEntity>> getList(String filter,
      {int page = 1, int? pageSize});
  Future<void> post(CfopEntity cfop);
  Future<void> put(CfopEntity cfop);
  Future<void> delete(String id);
}

class CfopDatasourceImpl implements CfopDatasource {
  const CfopDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<PagedResult<CfopEntity>> getList(String filter,
      {int page = 1, int? pageSize}) async {
    final params = [
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'page=$page',
      if (pageSize != null) 'pageSize=$pageSize',
    ];
    final json = await client.get('/api/cfop?${params.join('&')}');
    return PagedResult.fromJson(json, CfopEntity.fromJson);
  }

  /// O código é digitado pelo usuário (409 se já existir — inclui excluídos).
  @override
  Future<void> post(CfopEntity cfop) async {
    await client.post('/api/cfop', cfop.toCreateJson());
  }

  @override
  Future<void> put(CfopEntity cfop) async {
    await client.put('/api/cfop/${cfop.id}', cfop.toJson());
  }

  @override
  Future<void> delete(String id) async {
    await client.delete('/api/cfop/$id');
  }
}
