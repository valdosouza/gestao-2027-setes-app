import 'package:core/core.dart';

import '../../../../shared/field_config/entity/field_config_entity.dart';
import '../../../../shared/interface_vitrine/interface_vitrine_entity.dart';

/// Datasource do painel de campos configuráveis: /api/interface-fields.
/// Módulo do CLIENTE (decisão 9 — privilégio da tela, sem super).
abstract class InterfaceFieldsDatasource {
  /// Página da vitrine (paginação D3 — a API paginou a vitrine nesta onda):
  /// [pageSize] null deixa a API resolver a config page_size do usuário (D4).
  Future<PagedResult<InterfaceVitrineEntity>> vitrine(String filter,
      {int page = 1, int? pageSize});
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
  Future<PagedResult<InterfaceVitrineEntity>> vitrine(String filter,
      {int page = 1, int? pageSize}) async {
    final params = [
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'page=$page',
      if (pageSize != null) 'pageSize=$pageSize',
    ];
    final json = await client.get('/api/interface-fields?${params.join('&')}');
    return PagedResult.fromJson(json, InterfaceVitrineEntity.fromJson);
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
