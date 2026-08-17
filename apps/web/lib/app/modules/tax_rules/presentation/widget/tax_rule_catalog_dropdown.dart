import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../domain/entity/tax_rule_catalogs.dart';

/// Combo de catálogo fiscal (CST/CSOSN/modalidade/desoneração): opções do
/// GET /catalogs com rótulo "código - descrição" (texto do banco central —
/// não se traduz, decisão 26). [allowEmpty] acrescenta a opção "Não
/// informado" ('' → null no draft); valor fora do catálogo cai para vazio
/// em vez de quebrar o build (mesma proteção do EntityTaxTab).
class TaxRuleCatalogDropdown extends StatelessWidget {
  const TaxRuleCatalogDropdown({
    required this.label,
    required this.entries,
    required this.value,
    required this.onChanged,
    this.allowEmpty = true,
    super.key,
  });

  final String label;
  final List<CatalogEntry> entries;

  /// id escolhido (null = não informado).
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool allowEmpty;

  @override
  Widget build(BuildContext context) {
    final ids = [if (allowEmpty) '', for (final e in entries) e.id];
    final labels = {for (final e in entries) e.id: e.label};
    final current =
        value != null && ids.contains(value) ? value : (allowEmpty ? '' : null);
    return SetesDropdown<String>(
      label: label,
      value: current,
      items: ids,
      itemLabel: (id) =>
          id.isEmpty ? 'forms.taxRules.notSet'.tr() : (labels[id] ?? id),
      onChanged: (sel) =>
          onChanged(sel == null || sel.isEmpty ? null : sel),
    );
  }
}
