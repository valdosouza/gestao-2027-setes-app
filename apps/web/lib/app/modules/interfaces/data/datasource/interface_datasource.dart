import 'package:core/core.dart';

import '../../domain/entity/interface_entity.dart';
import '../../domain/entity/privilege_entity.dart';

/// Datasource remoto de Interface: /api/interfaces na setes-api.
/// Acesso exclusivo para role='super' (guard isSuper() no backend).
abstract class InterfaceDatasource {
  Future<List<InterfaceEntity>> getList(String filter);
  Future<int> post(InterfaceEntity entity);
  Future<void> put(InterfaceEntity entity);
  Future<void> delete(int id);

  /// Lista de apoio dos checkboxes de privilégios (tb_privilege).
  Future<List<PrivilegeEntity>> getPrivileges();
}

class InterfaceDatasourceImpl implements InterfaceDatasource {
  const InterfaceDatasourceImpl({required this.client});

  final ApiClient client;

  Map<String, dynamic> _body(InterfaceEntity entity) => {
        'groupDefault': entity.groupDefault,
        'i18nKey':      entity.i18nKey,
        'description':  entity.description,
        'kind':         entity.kind,
        'position':     entity.position,
        'privilegeIds': entity.privilegeIds,
      };

  @override
  Future<List<InterfaceEntity>> getList(String filter) async {
    final query = filter.isNotEmpty ? '?filter=${Uri.encodeComponent(filter)}' : '';
    final json = await client.get('/api/interfaces$query');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => InterfaceEntity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// O id é gerado pelo backend (MAX+1) — o body não envia id.
  @override
  Future<int> post(InterfaceEntity entity) async {
    final json = await client.post('/api/interfaces', _body(entity));
    return (json['data']['id'] as num).toInt();
  }

  @override
  Future<void> put(InterfaceEntity entity) async {
    await client.put('/api/interfaces/${entity.id}', _body(entity));
  }

  @override
  Future<void> delete(int id) async {
    await client.delete('/api/interfaces/$id');
  }

  @override
  Future<List<PrivilegeEntity>> getPrivileges() async {
    final json = await client.get('/api/privileges');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => PrivilegeEntity.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
