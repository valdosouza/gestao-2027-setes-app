import 'package:core/core.dart';

import '../../domain/entity/module_entity.dart';

/// Datasource remoto de Módulo de Menu: /api/modules na setes-api
/// (adminGuard + flag 'modules' — tela do ADMIN do cliente, D2).
abstract class ModuleDatasource {
  /// Página da lista (paginação D3): [pageSize] null deixa a API resolver a
  /// config page_size do usuário (D4).
  Future<PagedResult<ModuleEntity>> getList(String filter,
      {int page = 1, int? pageSize});

  /// Interfaces ELEGÍVEIS ao vínculo (contratadas, kind 'T', fora do Super).
  Future<List<ModuleInterfaceOption>> interfaceOptions();
  Future<int> post(ModuleEntity module);
  Future<void> put(ModuleEntity module);
  Future<void> delete(int id);
}

class ModuleDatasourceImpl implements ModuleDatasource {
  const ModuleDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<PagedResult<ModuleEntity>> getList(String filter,
      {int page = 1, int? pageSize}) async {
    final params = [
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'page=$page',
      if (pageSize != null) 'pageSize=$pageSize',
    ];
    final json = await client.get('/api/modules?${params.join('&')}');
    return PagedResult.fromJson(json, ModuleEntity.fromJson);
  }

  @override
  Future<List<ModuleInterfaceOption>> interfaceOptions() async {
    final json = await client.get('/api/modules/interface-lookup');
    return [
      for (final row in json['data'] as List<dynamic>? ?? [])
        ModuleInterfaceOption.fromJson(row as Map<String, dynamic>),
    ];
  }

  /// A ORDEM de [ModuleEntity.interfaceIds] é a ordem do menu (D3);
  /// o id do módulo é gerado pelo backend (MAX+1) — o body não envia id.
  Map<String, dynamic> _body(ModuleEntity module) => {
        'description':  module.description,
        'position':     module.position,
        'imageIcon':    module.imageIcon,
        'interfaceIds': module.interfaceIds,
      };

  @override
  Future<int> post(ModuleEntity module) async {
    final json = await client.post('/api/modules', _body(module));
    return (json['data']['id'] as num).toInt();
  }

  @override
  Future<void> put(ModuleEntity module) async {
    await client.put('/api/modules/${module.id}', _body(module));
  }

  @override
  Future<void> delete(int id) async {
    await client.delete('/api/modules/$id');
  }
}
