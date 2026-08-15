import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../domain/entity/module_entity.dart';

/// Rótulo da interface vinculada: tradução do catálogo com fallback na
/// description (decisão 26); vinculada que perdeu a elegibilidade (fora do
/// lookup) aparece pelo id. Usado pela seção e pela âncora do 422 na página.
String moduleInterfaceLabel(List<ModuleInterfaceOption> options, int id) {
  for (final option in options) {
    if (option.id == id) {
      return trCatalog(option.i18nKey, option.description ?? '$id',
          prefix: 'menu.interfaces');
    }
  }
  return '#$id';
}

/// Seção "Telas do módulo" do cadastro de Módulos de Menu (D3 — vínculo
/// ORDENÁVEL): lista ORDENADA das interfaces vinculadas — a ordem visual É o
/// array interfaceIds enviado no salvar — com setas subir/descer e remover
/// por linha; "Adicionar tela" abre o lookup filtrável (showSetesLookup)
/// alimentado pelas interfaces ELEGÍVEIS, escondendo as já vinculadas.
///
/// O ESTADO (a lista de ids) vive na PÁGINA (regra do extraChildren da
/// fábrica): a seção só renderiza [interfaceIds] e notifica [onChanged].
/// Controles fora da sequência de Tab (mesma regra dos checkboxes).
class ModuleInterfacesSection extends StatelessWidget {
  const ModuleInterfacesSection({
    required this.options,
    required this.interfaceIds,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  /// Interfaces ELEGÍVEIS (GET /api/modules/interface-lookup) — picker +
  /// resolução de rótulo das vinculadas.
  final List<ModuleInterfaceOption> options;

  /// Ids vinculados NA ORDEM do menu (estado da página).
  final List<int> interfaceIds;
  final void Function(List<int> interfaceIds) onChanged;

  /// false durante o saving (desabilita os controles).
  final bool enabled;

  String _labelOf(int id) => moduleInterfaceLabel(options, id);

  void _move(int index, int delta) {
    final ids = List<int>.of(interfaceIds);
    final id = ids.removeAt(index);
    ids.insert(index + delta, id);
    onChanged(ids);
  }

  void _remove(int index) =>
      onChanged(List<int>.of(interfaceIds)..removeAt(index));

  Future<void> _add(BuildContext context) async {
    final linked = interfaceIds.toSet();
    final available = [
      for (final option in options)
        if (!linked.contains(option.id)) option,
    ];
    final picked = await showSetesLookup<ModuleInterfaceOption>(
      context: context,
      title: 'lookup.moduleScreens'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      // Elegíveis já carregadas: filtro incremental LOCAL pelo rótulo
      // traduzido e pelo grupo padrão.
      onSearch: (filter) async {
        final query = filter.trim().toLowerCase();
        if (query.isEmpty) return available;
        return [
          for (final option in available)
            if (_labelOf(option.id).toLowerCase().contains(query) ||
                (option.groupDefault ?? '').toLowerCase().contains(query))
              option,
        ];
      },
      itemId: (option) => option.id,
      itemLabel: (option) => _labelOf(option.id),
    );
    if (picked != null) onChanged([...interfaceIds, picked.id]);
  }

  @override
  Widget build(BuildContext context) => ExcludeFocusTraversal(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SetesText('forms.module.screens'.tr()),
            ),
            SetesText('forms.module.screensHint'.tr()),
            const SizedBox(height: 8),
            if (interfaceIds.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: SetesText('forms.module.screensEmpty'.tr()),
              )
            else
              for (final (index, id) in interfaceIds.indexed)
                SetesListTile(
                  leading: CircleAvatar(child: SetesText('${index + 1}')),
                  title: SetesText(_labelOf(id)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_upward),
                        tooltip: 'forms.module.moveUp'.tr(),
                        onPressed: enabled && index > 0
                            ? () => _move(index, -1)
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_downward),
                        tooltip: 'forms.module.moveDown'.tr(),
                        onPressed: enabled && index < interfaceIds.length - 1
                            ? () => _move(index, 1)
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'forms.module.removeScreen'.tr(),
                        onPressed: enabled ? () => _remove(index) : null,
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 8),
            SetesButton(
              label: 'forms.module.addScreen'.tr(),
              icon: Icons.add,
              onPressed: enabled ? () => _add(context) : null,
            ),
          ],
        ),
      );
}
