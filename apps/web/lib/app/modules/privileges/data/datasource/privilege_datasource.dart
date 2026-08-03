import 'package:core/core.dart';

import '../../domain/entity/privilege_entity.dart';

/// Datasource remoto de Privilégio: /api/privileges na setes-api.
/// Acesso exclusivo para role='super' (guard isSuper() no backend).
abstract class PrivilegeDatasource {
  /// Página da lista (paginação D3): [pageSize] null deixa a API resolver a
  /// config page_size do usuário (D4).
  Future<PagedResult<PrivilegeEntity>> getList(String filter,
      {int page = 1, int? pageSize});
  Future<int> post(PrivilegeEntity privilege);
  Future<void> put(PrivilegeEntity privilege);
  Future<void> delete(int id);
}

class PrivilegeDatasourceImpl implements PrivilegeDatasource {
  const PrivilegeDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<PagedResult<PrivilegeEntity>> getList(String filter,
      {int page = 1, int? pageSize}) async {
    final params = [
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'page=$page',
      if (pageSize != null) 'pageSize=$pageSize',
    ];
    final json = await client.get('/api/privileges?${params.join('&')}');
    return PagedResult.fromJson(json, PrivilegeEntity.fromJson);
  }

  /// O id é gerado pelo backend (MAX+1) — o body não envia id.
  @override
  Future<int> post(PrivilegeEntity privilege) async {
    final json = await client.post('/api/privileges', {
      'description': privilege.description,
    });
    return (json['data']['id'] as num).toInt();
  }

  @override
  Future<void> put(PrivilegeEntity privilege) async {
    await client.put('/api/privileges/${privilege.id}', {
      'description': privilege.description,
    });
  }

  @override
  Future<void> delete(int id) async {
    await client.delete('/api/privileges/$id');
  }
}
