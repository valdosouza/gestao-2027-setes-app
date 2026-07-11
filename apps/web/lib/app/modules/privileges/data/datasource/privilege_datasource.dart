import 'package:core/core.dart';

import '../../domain/entity/privilege_entity.dart';

/// Datasource remoto de Privilégio: /api/privileges na setes-api.
/// Acesso exclusivo para role='super' (guard isSuper() no backend).
abstract class PrivilegeDatasource {
  Future<List<PrivilegeEntity>> getList(String filter);
  Future<int> post(PrivilegeEntity privilege);
  Future<void> put(PrivilegeEntity privilege);
  Future<void> delete(int id);
}

class PrivilegeDatasourceImpl implements PrivilegeDatasource {
  const PrivilegeDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<List<PrivilegeEntity>> getList(String filter) async {
    final query = filter.isNotEmpty ? '?filter=${Uri.encodeComponent(filter)}' : '';
    final json = await client.get('/api/privileges$query');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => PrivilegeEntity.fromJson(e as Map<String, dynamic>))
        .toList();
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
