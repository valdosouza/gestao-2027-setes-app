import 'package:core/core.dart';

import '../../../../shared/interface_config/entity/interface_config_entity.dart';
import '../../../../shared/interface_vitrine/interface_vitrine_entity.dart';

/// Datasource do painel de configurações do sistema: /api/interface-configs
/// (Framework de Configurações, decisões 7 e 9). Módulo do CLIENTE — admin
/// edita o valor da institution; usuário comum os próprios overrides
/// scope 'U' (enforcement na API).
abstract class InterfaceConfigsDatasource {
  Future<List<InterfaceVitrineEntity>> vitrine(String filter);
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
  Future<List<InterfaceVitrineEntity>> vitrine(String filter) async {
    final query = filter.isNotEmpty ? '?filter=${Uri.encodeComponent(filter)}' : '';
    final json = await client.get('/api/interface-configs$query');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => InterfaceVitrineEntity.fromJson(e as Map<String, dynamic>))
        .toList();
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
