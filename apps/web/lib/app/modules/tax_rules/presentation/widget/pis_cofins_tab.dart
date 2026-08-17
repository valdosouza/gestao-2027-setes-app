import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../domain/entity/tax_rule_catalogs.dart';
import '../../domain/entity/tax_rule_draft.dart';
import 'tax_rule_catalog_dropdown.dart';

/// Aba PIS/COFINS — os DOIS tributos na MESMA aba (decisão "PIS = COFINS":
/// mesma forma, kind distingue). Cada um tem o próprio toggle; o payload
/// junta os ligados no array pisCofins [{kind:'P'},{kind:'C'}].
class PisCofinsTab extends StatefulWidget {
  const PisCofinsTab({
    required this.pis,
    required this.cofins,
    required this.catalogs,
    required this.onPisChanged,
    required this.onCofinsChanged,
    super.key,
  });

  /// null = tributo não definido (toggle desligado).
  final PisCofinsData? pis;
  final PisCofinsData? cofins;
  final TaxRuleCatalogs catalogs;
  final ValueChanged<PisCofinsData?> onPisChanged;
  final ValueChanged<PisCofinsData?> onCofinsChanged;

  @override
  State<PisCofinsTab> createState() => _PisCofinsTabState();
}

class _PisCofinsTabState extends State<PisCofinsTab> {
  late final TextEditingController _pisAliq;
  late final TextEditingController _cofinsAliq;

  /// Últimas fatias vistas — religar o toggle restaura o que foi digitado.
  PisCofinsData _lastPis = const PisCofinsData(kind: 'P');
  PisCofinsData _lastCofins = const PisCofinsData(kind: 'C');

  @override
  void initState() {
    super.initState();
    _lastPis = widget.pis ?? const PisCofinsData(kind: 'P');
    _lastCofins = widget.cofins ?? const PisCofinsData(kind: 'C');
    _pisAliq = TextEditingController(text: _lastPis.aliq);
    _cofinsAliq = TextEditingController(text: _lastCofins.aliq);
  }

  @override
  void dispose() {
    _pisAliq.dispose();
    _cofinsAliq.dispose();
    super.dispose();
  }

  void _emitPis(PisCofinsData updated) {
    _lastPis = updated;
    widget.onPisChanged(updated);
  }

  void _emitCofins(PisCofinsData updated) {
    _lastCofins = updated;
    widget.onCofinsChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final pis = widget.pis;
    final cofins = widget.cofins;

    Widget field(Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 16), child: child);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ---------------- PIS ----------------
        ExcludeFocusTraversal(
          child: SetesSwitch(
            label: 'forms.taxRules.definePis'.tr(),
            subtitle: 'forms.taxRules.defineHint'.tr(),
            value: pis != null,
            onChanged: (checked) =>
                widget.onPisChanged(checked ? _lastPis : null),
          ),
        ),
        const SizedBox(height: 16),
        if (pis != null) ...[
          field(TaxRuleCatalogDropdown(
            label: 'forms.taxRules.pisCst'.tr(),
            entries: widget.catalogs.pis,
            value: pis.cst,
            onChanged: (sel) => _emitPis(pis.copyWith(cst: () => sel)),
          )),
          field(SetesTextField(
            label: 'forms.taxRules.pisAliq'.tr(),
            controller: _pisAliq,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            onChanged: (t) => _emitPis(pis.copyWith(aliq: t)),
          )),
        ],
        const Divider(),
        const SizedBox(height: 16),
        // --------------- COFINS ---------------
        ExcludeFocusTraversal(
          child: SetesSwitch(
            label: 'forms.taxRules.defineCofins'.tr(),
            subtitle: 'forms.taxRules.defineHint'.tr(),
            value: cofins != null,
            onChanged: (checked) =>
                widget.onCofinsChanged(checked ? _lastCofins : null),
          ),
        ),
        const SizedBox(height: 16),
        if (cofins != null) ...[
          field(TaxRuleCatalogDropdown(
            label: 'forms.taxRules.cofinsCst'.tr(),
            entries: widget.catalogs.cofins,
            value: cofins.cst,
            onChanged: (sel) =>
                _emitCofins(cofins.copyWith(cst: () => sel)),
          )),
          field(SetesTextField(
            label: 'forms.taxRules.cofinsAliq'.tr(),
            controller: _cofinsAliq,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onChanged: (t) => _emitCofins(cofins.copyWith(aliq: t)),
          )),
        ],
      ],
    );
  }
}
