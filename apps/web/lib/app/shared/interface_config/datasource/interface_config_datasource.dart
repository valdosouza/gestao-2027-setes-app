import 'package:core/core.dart';

import '../entity/interface_config_entity.dart';

/// Datasource da config resolvida do SISTEMA (Framework de Configurações,
/// decisão 4). Bind GLOBAL no AppModule: qualquer tela consome pela chave
/// do módulo (molde do FieldConfigDatasource da Fase 2).
abstract class InterfaceConfigDatasource {
  /// Configs da interface pela CHAVE do módulo (ex.: 'customers').
  /// Lista vazia = módulo sem catálogo (tela usa os padrões do código).
  Future<List<InterfaceConfigEntity>> byModule(String moduleKey);
}

class InterfaceConfigDatasourceImpl implements InterfaceConfigDatasource {
  const InterfaceConfigDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<List<InterfaceConfigEntity>> byModule(String moduleKey) async {
    final json = await client.get('/api/interface-configs/key/$moduleKey');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => InterfaceConfigEntity.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
