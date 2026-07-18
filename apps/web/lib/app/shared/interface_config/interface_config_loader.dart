import 'package:flutter/widgets.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'datasource/interface_config_datasource.dart';
import 'entity/interface_config_entity.dart';

/// Mixin do ENGINE de configurações do sistema (Framework de Configurações,
/// decisão 4) para as páginas: carrega a config resolvida do módulo na
/// montagem e rebuilda quando chega. Falha na consulta NÃO quebra a tela —
/// ela segue com os padrões do código (molde do FieldConfigLoader).
///
/// Uso: `class _XPageState extends State<XPage> with InterfaceConfigLoader {`
/// e no initState: `loadInterfaceConfig('customers')`. No build, leia por
/// [configContent]/[configBool].
mixin InterfaceConfigLoader<T extends StatefulWidget> on State<T> {
  /// Config resolvida do módulo ([] até carregar ou sem catálogo).
  List<InterfaceConfigEntity> interfaceConfig = const [];

  Future<void> loadInterfaceConfig(String moduleKey) async {
    try {
      final config =
          await Modular.get<InterfaceConfigDatasource>().byModule(moduleKey);
      if (mounted && config.isNotEmpty) {
        setState(() => interfaceConfig = config);
      }
    } catch (_) {
      // Sem config (ex.: API fora) → tela permanece no modo padrão do código.
    }
  }

  /// Valor efetivo da configuração [name]; [fallback] quando não carregada.
  String configContent(String name, {String fallback = ''}) {
    for (final config in interfaceConfig) {
      if (config.name == name) return config.content;
    }
    return fallback;
  }

  /// Atalho para configs Boolean ('S'/'N').
  bool configBool(String name) => configContent(name) == 'S';
}
