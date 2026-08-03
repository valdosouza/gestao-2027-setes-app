import 'package:core/core.dart';

import '../../../../shared/interface_config/entity/interface_config_entity.dart';
import '../../../../shared/interface_vitrine/interface_vitrine_entity.dart';

/// Datasource do painel de configurações do sistema: /api/interface-configs
/// (Framework de Configurações, decisões 7 e 9). Módulo do CLIENTE — admin
/// edita o valor da institution; usuário comum os próprios overrides
/// scope 'U' (enforcement na API).
abstract class InterfaceConfigsDatasource {
  /// Página da vitrine (paginação D3 — a API paginou a vitrine nesta onda):
  /// [pageSize] null deixa a API resolver a config page_size do usuário (D4).
  Future<PagedResult<InterfaceVitrineEntity>> vitrine(String filter,
      {int page = 1, int? pageSize});
  Future<List<InterfaceConfigEntity>> configs(int interfaceId);

  /// Salva o valor de UMA configuração. [content] null = volta a herdar
  /// (institution → default). [asUser] true = override pessoal (scope 'U');
  /// false = valor da institution (admin).
  Future<void> saveValue({
    required int interfaceId,
    required String name,
    required String? content,
    required bool asUser,
  });
}

class InterfaceConfigsDatasourceImpl implements InterfaceConfigsDatasource {
  const InterfaceConfigsDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<PagedResult<InterfaceVitrineEntity>> vitrine(String filter,
      {int page = 1, int? pageSize}) async {
    final params = [
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'page=$page',
      if (pageSize != null) 'pageSize=$pageSize',
    ];
    final json = await client.get('/api/interface-configs?${params.join('&')}');
    return PagedResult.fromJson(json, InterfaceVitrineEntity.fromJson);
  }

  @override
  Future<List<InterfaceConfigEntity>> configs(int interfaceId) async {
    final json = await client.get('/api/interface-configs/$interfaceId');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => InterfaceConfigEntity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveValue({
    required int interfaceId,
    required String name,
    required String? content,
    required bool asUser,
  }) async {
    await client.put('/api/interface-configs/$interfaceId/$name', {
      'content': content,
      'target':  asUser ? 'U' : 'I',
    });
  }
}
