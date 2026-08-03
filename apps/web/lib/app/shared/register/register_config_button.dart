import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../interface_config/datasource/interface_config_datasource.dart';

/// Engrenagem padrão das listas (Framework de Configurações, decisão 11 —
/// ajuste 2026-08-03): o ícone SÓ aparece se o módulo tem configurações no
/// catálogo, para que a engrenagem visível signifique "existe algo a
/// configurar" (antes ela abria um painel vazio). A consulta reaproveita o
/// GET resolvido do módulo; lista vazia = módulo sem catálogo = sem ícone.
///
/// Peça única para a fábrica ([RegisterSearchPage]) e para as telas de
/// processo/árvore que montavam a engrenagem manualmente.
class RegisterConfigButton extends StatefulWidget {
  const RegisterConfigButton({required this.moduleKey, super.key});

  /// Chave do módulo (ex.: 'customers') — mesma do painel interface-configs.
  final String moduleKey;

  /// Cache de sessão módulo → tem catálogo? (o catálogo só muda pelo Super
  /// na tela de Interfaces; não vale um GET a cada abertura de tela).
  static final Map<String, bool> _hasConfigs = {};

  @override
  State<RegisterConfigButton> createState() => _RegisterConfigButtonState();
}

class _RegisterConfigButtonState extends State<RegisterConfigButton> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    final cached = RegisterConfigButton._hasConfigs[widget.moduleKey];
    if (cached != null) {
      _visible = cached;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final config = await Modular.get<InterfaceConfigDatasource>()
          .byModule(widget.moduleKey);
      RegisterConfigButton._hasConfigs[widget.moduleKey] = config.isNotEmpty;
      if (mounted && config.isNotEmpty) setState(() => _visible = true);
    } catch (_) {
      // API fora → sem engrenagem nesta abertura (sem cache: tenta de novo
      // na próxima montagem — mesma tolerância do InterfaceConfigLoader).
    }
  }

  /// Painel filtrado no módulo; o retorno SEM arguments faz o módulo
  /// chamador recair no título trCatalog padrão.
  void _openConfigs() {
    Modular.to.navigate('/home/interface-configs/', arguments: {
      'title': trCatalog('interface-configs', 'Interface Configs',
          prefix: 'menu.interfaces'),
      'moduleKey': widget.moduleKey,
      'returnTo': Modular.to.path,
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(Icons.settings_outlined),
      tooltip: 'register.configTooltip'.tr(),
      onPressed: _openConfigs,
    );
  }
}
