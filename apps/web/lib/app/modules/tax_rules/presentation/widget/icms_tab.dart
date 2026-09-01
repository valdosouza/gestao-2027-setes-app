import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../domain/entity/tax_rule_catalogs.dart';
import '../../domain/entity/tax_rule_draft.dart';
import 'tax_rule_catalog_dropdown.dart';

/// Aba ICMS — peça presente = a regra DEFINE o tributo (decisão 23:
/// presença = incidência; toggle desligado = peça ausente no payload).
/// CST (regime normal) e/ou CSOSN (Simples) obrigatório quando ligada.
class IcmsTab extends StatefulWidget {
  const IcmsTab({
    required this.value,
    required this.restore,
    required this.catalogs,
    required this.onChanged,
    super.key,
  });

  /// null = tributo não definido (toggle desligado).
  final IcmsData? value;

  /// Última fatia vista, guardada no FORM (sobrevive ao descarte da aba
  /// pelo TabBarView — L3 dos gates): religar o toggle restaura daqui.
  final IcmsData restore;
  final TaxRuleCatalogs catalogs;
  final ValueChanged<IcmsData?> onChanged;

  @override
  State<IcmsTab> createState() => _IcmsTabState();
}

class _IcmsTabState extends State<IcmsTab> {
  late final TextEditingController _aliq;
  late final TextEditingController _aliqReduction;
  late final TextEditingController _baseReduction;
  late final TextEditingController _deferredAliq;

  @override
  void initState() {
    super.initState();
    // Toggle desligado: os controllers nascem da memória do form, para o
    // religar exibir exatamente o que será restaurado.
    final init = widget.value ?? widget.restore;
    _aliq = TextEditingController(text: init.aliq);
    _aliqReduction = TextEditingController(text: init.aliqReduction);
    _baseReduction = TextEditingController(text: init.baseReduction);
    _deferredAliq = TextEditingController(text: init.deferredAliq);
  }

  @override
  void dispose() {
    _aliq.dispose();
    _aliqReduction.dispose();
    _baseReduction.dispose();
    _deferredAliq.dispose();
    super.dispose();
  }

  void _emit(IcmsData updated) => widget.onChanged(updated);

  List<SetesRadioOption<String>> get _yesNo => [
        SetesRadioOption(value: 'S', label: 'register.yes'.tr()),
        SetesRadioOption(value: 'N', label: 'register.no'.tr()),
      ];

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
            label: 'forms.taxRules.defineIcms'.tr(),
            subtitle: 'forms.taxRules.defineHint'.tr(),
            value: on,
            onChanged: (checked) =>
                widget.onChanged(checked ? widget.restore : null),
          ),
        ),
        const SizedBox(height: 16),
        if (on)
          FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // D39.3 — o form se adapta ao regime do estabelecimento:
                // Simples (CRT 1/2) só CSOSN; Normal (CRT 3) só CST;
                // regime não configurado (null) mostra os dois (fallback).
                // O valor do campo oculto NÃO é apagado — regra é agnóstica
                // ao regime e o motor despacha pelo CRT ao faturar (D37).
                if (!widget.catalogs.isSimples)
                  field(TaxRuleCatalogDropdown(
                    label: 'forms.taxRules.icmsCst'.tr(),
                    entries: widget.catalogs.icmsNr,
                    value: v.cstNr,
                    onChanged: (sel) =>
                        _emit(v.copyWith(cstNr: () => sel)),
                  )),
                if (!widget.catalogs.isNormal)
                  field(TaxRuleCatalogDropdown(
                    label: 'forms.taxRules.icmsCsosn'.tr(),
                    entries: widget.catalogs.icmsSn,
                    value: v.csosn,
                    onChanged: (sel) =>
                        _emit(v.copyWith(csosn: () => sel)),
                  )),
                field(TaxRuleCatalogDropdown(
                  label: 'forms.taxRules.icmsModBc'.tr(),
                  entries: widget.catalogs.modBc,
                  value: v.modBc,
                  onChanged: (sel) =>
                      _emit(v.copyWith(modBc: () => sel)),
                )),
                field(TaxRuleCatalogDropdown(
                  label: 'forms.taxRules.icmsDischarge'.tr(),
                  entries: widget.catalogs.discharge,
                  value: v.dischargeId,
                  onChanged: (sel) =>
                      _emit(v.copyWith(dischargeId: () => sel)),
                )),
                field(FocusTraversalOrder(
                  order: const NumericFocusOrder(0),
                  child: SetesTextField(
                    label: 'forms.taxRules.icmsAliq'.tr(),
                    controller: _aliq,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    textInputAction: TextInputAction.next,
                    onChanged: (t) => _emit(v.copyWith(aliq: t)),
                  ),
                )),
                field(FocusTraversalOrder(
                  order: const NumericFocusOrder(1),
                  child: SetesTextField(
                    label: 'forms.taxRules.icmsAliqReduction'.tr(),
                    controller: _aliqReduction,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    textInputAction: TextInputAction.next,
                    onChanged: (t) =>
                        _emit(v.copyWith(aliqReduction: t)),
                  ),
                )),
                field(FocusTraversalOrder(
                  order: const NumericFocusOrder(2),
                  child: SetesTextField(
                    label: 'forms.taxRules.icmsBaseReduction'.tr(),
                    controller: _baseReduction,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    textInputAction: TextInputAction.next,
                    onChanged: (t) =>
                        _emit(v.copyWith(baseReduction: t)),
                  ),
                )),
                field(SetesRadioGroup<String>(
                  label: 'forms.taxRules.icmsDeferred'.tr(),
                  value: v.deferred,
                  options: _yesNo,
                  onChanged: (sel) =>
                      _emit(v.copyWith(deferred: sel ?? 'N')),
                )),
                if (v.deferred == 'S')
                  field(FocusTraversalOrder(
                    order: const NumericFocusOrder(3),
                    child: SetesTextField(
                      label: 'forms.taxRules.icmsDeferredAliq'.tr(),
                      controller: _deferredAliq,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      textInputAction: TextInputAction.done,
                      onChanged: (t) =>
                          _emit(v.copyWith(deferredAliq: t)),
                    ),
                  )),
                field(SetesRadioGroup<String>(
                  label: 'forms.taxRules.icmsHighlight'.tr(),
                  value: v.highlight,
                  options: _yesNo,
                  onChanged: (sel) =>
                      _emit(v.copyWith(highlight: sel ?? 'N')),
                )),
              ],
            ),
          ),
      ],
    );
  }
}
