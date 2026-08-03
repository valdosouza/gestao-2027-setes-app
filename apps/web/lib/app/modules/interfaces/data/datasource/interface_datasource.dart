import 'package:core/core.dart';

import '../../domain/entity/interface_config_catalog_entity.dart';
import '../../domain/entity/interface_entity.dart';
import '../../domain/entity/privilege_entity.dart';

/// Datasource remoto de Interface: /api/interfaces na setes-api.
/// Acesso exclusivo para role='super' (guard isSuper() no backend).
abstract class InterfaceDatasource {
  /// Página da lista (paginação D3): [pageSize] null deixa a API resolver a
  /// config page_size do usuário (D4).
  Future<PagedResult<InterfaceEntity>> getList(String filter,
      {int page = 1, int? pageSize});
  Future<int> post(InterfaceEntity entity);
  Future<void> put(InterfaceEntity entity);
  Future<void> delete(int id);

  /// Lista de apoio dos checkboxes de privilégios (tb_privilege).
  Future<List<PrivilegeEntity>> getPrivileges();

  /// Catálogo de CONFIGURAÇÕES da interface (Framework de Configurações,
  /// decisões 6 e 7 — seção "Configurações", CRUD autônomo na edição).
  Future<List<InterfaceConfigCatalogEntity>> getConfigs(int interfaceId);
  Future<void> saveConfig(int interfaceId, InterfaceConfigCatalogEntity config);
  Future<void> deleteConfig(int interfaceId, String name);
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
  Future<PagedResult<InterfaceEntity>> getList(String filter,
      {int page = 1, int? pageSize}) async {
    final params = [
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'page=$page',
      if (pageSize != null) 'pageSize=$pageSize',
    ];
    final json = await client.get('/api/interfaces?${params.join('&')}');
    return PagedResult.fromJson(json, InterfaceEntity.fromJson);
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
    // Lista de apoio NÃO pagina (D6), mas o envelope agora traz pageSize
    // default 25 — pageSize=100 mantém o alcance dos checkboxes.
    final json = await client.get('/api/privileges?pageSize=100');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => PrivilegeEntity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<InterfaceConfigCatalogEntity>> getConfigs(int interfaceId) async {
    final json = await client.get('/api/interfaces/$interfaceId/configs');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) =>
            InterfaceConfigCatalogEntity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveConfig(
      int interfaceId, InterfaceConfigCatalogEntity config) async {
    await client.put(
        '/api/interfaces/$interfaceId/configs/${config.name}', config.toJson());
  }

  @override
  Future<void> deleteConfig(int interfaceId, String name) async {
    await client.delete('/api/interfaces/$interfaceId/configs/$name');
  }
}
