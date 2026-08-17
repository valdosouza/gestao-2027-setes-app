import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../domain/entity/tax_rule_catalogs.dart';
import '../../domain/entity/tax_rule_draft.dart';
import 'tax_rule_catalog_dropdown.dart';

/// Aba ICMS-ST — peça acessória do ICMS: só pode ser ligada com a peça
/// ICMS presente (422 da API — o toggle fica desabilitado sem ICMS).
class IcmsStTab extends StatefulWidget {
  const IcmsStTab({
    required this.value,
    required this.icmsOn,
    required this.catalogs,
    required this.onChanged,
    super.key,
  });

  /// null = tributo não definido (toggle desligado).
  final IcmsStData? value;

  /// A peça ICMS está ligada? (pré-requisito da ST.)
  final bool icmsOn;
  final TaxRuleCatalogs catalogs;
  final ValueChanged<IcmsStData?> onChanged;

  @override
  State<IcmsStTab> createState() => _IcmsStTabState();
}

class _IcmsStTabState extends State<IcmsStTab> {
  /// Última fatia vista — religar o toggle restaura a escolha (enquanto a
  /// aba está montada).
  IcmsStData _last = const IcmsStData();

  @override
  void initState() {
    super.initState();
    _last = widget.value ?? const IcmsStData();
  }

  void _emit(IcmsStData updated) {
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
            label: 'forms.taxRules.defineIcmsSt'.tr(),
            subtitle: widget.icmsOn
                ? 'forms.taxRules.defineHint'.tr()
                : 'forms.taxRules.stNeedsIcms'.tr(),
            value: on,
            enabled: widget.icmsOn,
            onChanged: (checked) =>
                widget.onChanged(checked ? _last : null),
          ),
        ),
        const SizedBox(height: 16),
        if (on) ...[
          field(TaxRuleCatalogDropdown(
            label: 'forms.taxRules.icmsStModBc'.tr(),
            entries: widget.catalogs.modBcSt,
            value: v.modBcSt,
            onChanged: (sel) => _emit(v.copyWith(modBcSt: () => sel)),
          )),
          field(SetesRadioGroup<String>(
            label: 'forms.taxRules.icmsStPropagate'.tr(),
            value: v.propagateBaseReduction,
            options: [
              SetesRadioOption(value: 'S', label: 'register.yes'.tr()),
              SetesRadioOption(value: 'N', label: 'register.no'.tr()),
            ],
            onChanged: (sel) =>
                _emit(v.copyWith(propagateBaseReduction: sel ?? 'N')),
          )),
        ],
      ],
    );
  }
}
