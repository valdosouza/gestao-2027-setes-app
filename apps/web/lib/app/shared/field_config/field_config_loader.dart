import 'package:flutter/widgets.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'datasource/field_config_datasource.dart';
import 'entity/field_config_entity.dart';

/// Mixin do ENGINE de campos configuráveis (decisão 7) para as páginas de
/// cadastro: carrega a config resolvida do módulo na montagem e rebuilda a
/// tela quando ela chega. Falha na consulta NÃO quebra a tela — ela monta
/// com os padrões do código (modo padrão).
///
/// Uso: `class _XPageState extends State<XPage> with FieldConfigLoader {`
/// e no initState: `loadFieldConfig('countries')`. No build, passe os campos
/// por [applyFieldConfig] (shared/register/field_config_merge.dart).
mixin FieldConfigLoader<T extends StatefulWidget> on State<T> {
  /// Config resolvida do módulo ([] até carregar ou quando não há catálogo).
  List<FieldConfigEntity> fieldConfig = const [];

  Future<void> loadFieldConfig(String moduleKey) async {
    try {
      final config =
          await Modular.get<FieldConfigDatasource>().byModule(moduleKey);
      if (mounted && config.isNotEmpty) {
        setState(() => fieldConfig = config);
      }
    } catch (_) {
      // Sem config (ex.: API fora) → tela permanece no modo padrão do código.
    }
  }
}
