import 'package:core/core.dart';

import '../../../../shared/field_config/entity/field_config_entity.dart';
import '../../domain/entity/interface_vitrine_entity.dart';

/// Datasource do painel de campos configuráveis: /api/interface-fields.
/// Módulo do CLIENTE (decisão 9 — privilégio da tela, sem super).
abstract class InterfaceFieldsDatasource {
  Future<List<InterfaceVitrineEntity>> vitrine(String filter);
  Future<List<FieldConfigEntity>> fields(int interfaceId);

  /// Salva a config de um campo. required true → 'S' (aperta);
  /// false/null → herda o catálogo (decisão 2: nunca afrouxa o técnico).
  Future<void> saveField({
    required int interfaceId,
    required String fieldName,
    String? caption,
    bool required = false,
    String? mask,
  });
}

class InterfaceFieldsDatasourceImpl implements InterfaceFieldsDatasource {
  const InterfaceFieldsDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<List<InterfaceVitrineEntity>> vitrine(String filter) async {
    final query = filter.isNotEmpty ? '?filter=${Uri.encodeComponent(filter)}' : '';
    final json = await client.get('/api/interface-fields$query');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => InterfaceVitrineEntity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<FieldConfigEntity>> fields(int interfaceId) async {
    final json = await client.get('/api/interface-fields/$interfaceId');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => FieldConfigEntity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveField({
    required int interfaceId,
    required String fieldName,
    String? caption,
    bool required = false,
    String? mask,
  }) async {
    await client.put('/api/interface-fields/$interfaceId/$fieldName', {
      'fieldCaption': (caption == null || caption.isEmpty) ? null : caption,
      'required':     required ? 'S' : null,
      'mask':         (mask == null || mask.isEmpty) ? null : mask,
    });
  }
}
