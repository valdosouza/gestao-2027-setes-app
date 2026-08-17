import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../domain/entity/tax_rule_catalogs.dart';
import '../../domain/entity/tax_rule_draft.dart';
import 'tax_rule_catalog_dropdown.dart';

/// Aba IPI — CST obrigatório quando a peça está ligada (DTO da API).
class IpiTab extends StatefulWidget {
  const IpiTab({
    required this.value,
    required this.catalogs,
    required this.onChanged,
    super.key,
  });

  /// null = tributo não definido (toggle desligado).
  final IpiData? value;
  final TaxRuleCatalogs catalogs;
  final ValueChanged<IpiData?> onChanged;

  @override
  State<IpiTab> createState() => _IpiTabState();
}

class _IpiTabState extends State<IpiTab> {
  late final TextEditingController _aliq;

  /// Última fatia vista — religar o toggle restaura o que foi digitado.
  IpiData _last = const IpiData();

  @override
  void initState() {
    super.initState();
    _last = widget.value ?? const IpiData();
    _aliq = TextEditingController(text: _last.aliq);
  }

  @override
  void dispose() {
    _aliq.dispose();
    super.dispose();
  }

  void _emit(IpiData updated) {
    _last = updated;
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.value;
    final on = v != null;

    Widget field(Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 16), child: child);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ExcludeFocusTraversal(
          child: SetesSwitch(
            label: 'forms.taxRules.defineIpi'.tr(),
            subtitle: 'forms.taxRules.defineHint'.tr(),
            value: on,
            onChanged: (checked) =>
                widget.onChanged(checked ? _last : null),
          ),
        ),
        const SizedBox(height: 16),
        if (on) ...[
          field(TaxRuleCatalogDropdown(
            label: 'forms.taxRules.ipiCst'.tr(),
            entries: widget.catalogs.ipi,
            value: v.cst,
            onChanged: (sel) => _emit(v.copyWith(cst: () => sel)),
          )),
          field(FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: SetesTextField(
              label: 'forms.taxRules.ipiAliq'.tr(),
              controller: _aliq,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              onChanged: (t) => _emit(v.copyWith(aliq: t)),
            ),
          )),
        ],
      ],
    );
  }
}
