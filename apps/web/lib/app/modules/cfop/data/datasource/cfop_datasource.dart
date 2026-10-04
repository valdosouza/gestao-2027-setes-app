import 'package:core/core.dart';

import '../../../../shared/search/search_criterion.dart';
import '../../domain/entity/cfop_entity.dart';

/// Datasource remoto de CFOP: /api/cfop na setes-api.
/// Acesso exclusivo para role='super' (guard isSuper() no backend).
abstract class CfopDatasource {
  /// Página da lista (paginação D3): [pageSize] null deixa a API resolver a
  /// config page_size do usuário (D4).
  /// [criteria] = pesquisa avançada (D-BA1) — soma em E com [filter].
  Future<PagedResult<CfopEntity>> getList(String filter,
      {int page = 1,
      int? pageSize,
      SearchCriteriaValues criteria = SearchCriteriaValues.empty});
  Future<void> post(CfopEntity cfop);
  Future<void> put(CfopEntity cfop);
  Future<void> delete(String id);
}

class CfopDatasourceImpl implements CfopDatasource {
  const CfopDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<PagedResult<CfopEntity>> getList(String filter,
      {int page = 1,
      int? pageSize,
      SearchCriteriaValues criteria = SearchCriteriaValues.empty}) async {
    final params = [
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'page=$page',
      if (pageSize != null) 'pageSize=$pageSize',
      if (!criteria.isEmpty) criteria.toQueryParam(),
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
