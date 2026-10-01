import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import 'advanced_search_panel.dart';
import 'search_criterion.dart';

/// Chips dos critérios ATIVOS da pesquisa avançada (D-BA6): mostram o que
/// está estreitando a lista, removem um critério (x) ou todos ("limpar").
/// O filtro rápido não entra aqui — ele continua visível no próprio campo.
class SearchCriteriaChips extends StatelessWidget {
  const SearchCriteriaChips({
    required this.criteria,
    required this.values,
    required this.onChanged,
    super.key,
  });

  final List<SearchCriterion> criteria;
  final SearchCriteriaValues values;
  final void Function(SearchCriteriaValues values) onChanged;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    final active = [
      for (final c in criteria)
        if (values.values.containsKey(c.key)) c,
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final c in active)
          InputChip(
            label: SetesText(
                '${c.labelKey.tr()}: ${describeCriterionValue(c, values.values[c.key]!)}'),
            onDeleted: () => onChanged(values.without(c.key)),
          ),
        SetesButton(
          label: 'search.clear'.tr(),
          kind: SetesButtonKind.text,
          onPressed: () => onChanged(SearchCriteriaValues.empty),
        ),
      ],
    );
  }
}
