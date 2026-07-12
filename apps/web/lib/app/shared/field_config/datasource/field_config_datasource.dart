import 'package:core/core.dart';

import '../entity/field_config_entity.dart';

/// Datasource da config resolvida de campos (engine de montagem — decisão 7).
/// Bind GLOBAL no AppModule: toda tela consulta na montagem.
abstract class FieldConfigDatasource {
  /// Config da interface pela CHAVE do módulo (ex.: 'countries').
  /// Lista vazia = módulo sem catálogo (tela monta com os padrões do código).
  Future<List<FieldConfigEntity>> byModule(String moduleKey);
}

class FieldConfigDatasourceImpl implements FieldConfigDatasource {
  const FieldConfigDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<List<FieldConfigEntity>> byModule(String moduleKey) async {
    final json = await client.get('/api/interface-fields/key/$moduleKey');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => FieldConfigEntity.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
