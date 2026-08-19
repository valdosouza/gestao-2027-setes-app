import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/lookup/datasource/state_lookup_datasource.dart';
import '../../../../shared/lookup/entity/state_lookup_entity.dart';
import '../../domain/entity/tax_rule_draft.dart';

/// Ganchos de foco/marcação dos campos de texto da aba Seletor (mecânica
/// uma-pendência R3 e fields[] do servidor — Framework de Mensagens).
class SelectorTabHooks {
  final ncmFocus = FocusNode();
  final ncmKey = GlobalKey<FormFieldState<String>>();
  final productFocus = FocusNode();
  final productKey = GlobalKey<FormFieldState<String>>();
  final entityFocus = FocusNode();
  final entityKey = GlobalKey<FormFieldState<String>>();
  final cfopFocus = FocusNode();
  final cfopKey = GlobalKey<FormFieldState<String>>();

  void dispose() {
    ncmFocus.dispose();
    productFocus.dispose();
    entityFocus.dispose();
    cfopFocus.dispose();
  }
}

/// Aba "Seletor" — QUANDO a regra vale (decisão 1 da fase): origem,
/// finalidade, flags do destinatário e recortes opcionais (NCM, produto,
/// cliente, estado, CFOP, sentido). Campo vazio = CORINGA (a regra casa
/// com qualquer valor). Edita a fatia [TaxRuleSelectorData] do draft —
/// contrato value + onChanged (o draft vive no bloc do módulo).
class SelectorTab extends StatefulWidget {
  const SelectorTab({
    required this.value,
    required this.onChanged,
    required this.stateLookup,
    required this.hooks,
    super.key,
  });

  final TaxRuleSelectorData value;
  final ValueChanged<TaxRuleSelectorData> onChanged;
  final StateLookupDatasource stateLookup;
  final SelectorTabHooks hooks;

  @override
  State<SelectorTab> createState() => _SelectorTabState();
}

class _SelectorTabState extends State<SelectorTab> {
  late final TextEditingController _ncm;
  late final TextEditingController _product;
  late final TextEditingController _entity;
  late final TextEditingController _cfop;

  @override
  void initState() {
    super.initState();
    final v = widget.value;
    _ncm = TextEditingController(text: v.ncm);
    _product = TextEditingController(text: v.productId);
    _entity = TextEditingController(text: v.entityId);
    _cfop = TextEditingController(text: v.cfopId);
  }

  @override
  void dispose() {
    _ncm.dispose();
    _product.dispose();
    _entity.dispose();
    _cfop.dispose();
    super.dispose();
  }

  void _emit(TaxRuleSelectorData updated) => widget.onChanged(updated);

  Future<void> _pickState() async {
    final picked = await showSetesLookup<StateLookup>(
      context: context,
      title: 'lookup.states'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: widget.stateLookup.list,
      itemId: (s) => s.id,
      itemLabel: (s) => '${s.abbreviation ?? ''} · ${s.name ?? ''}',
    );
    if (picked != null) {
      _emit(widget.value.copyWith(
        stateId: () => picked.id,
        stateName: picked.name ?? '',
      ));
    }
  }

  List<SetesRadioOption<String>> get _yesNo => [
        SetesRadioOption(value: 'S', label: 'register.yes'.tr()),
        SetesRadioOption(value: 'N', label: 'register.no'.tr()),
      ];

  /// Inline SÓ marca (a mensagem do dialog é da pendency — R3).
  String? _ncmValidator(String? text) {
    final t = (text ?? '').trim();
    if (t.isEmpty) return null;
    return RegExp(r'^\d{2,8}$').hasMatch(t)
        ? null
        : 'forms.taxRules.ncmInvalid'.tr();
  }

  String? _optionalIntValidator(String? text) {
    final t = (text ?? '').trim();
    if (t.isEmpty) return null;
    final parsed = int.tryParse(t);
    return parsed == null || parsed <= 0
        ? 'register.invalidNumber'.tr()
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.value;
    final hooks = widget.hooks;

    Widget field(Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 16), child: child);

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Origem da mercadoria (tabela A da NF-e — match exato)
          field(SetesDropdown<String>(
            label: 'forms.taxRules.origin'.tr(),
            value: v.origin,
            items: const ['0', '1', '2', '3', '4', '5', '6', '7', '8'],
            itemLabel: (code) => 'forms.taxRules.origin$code'.tr(),
            onChanged: (sel) => _emit(v.copyWith(origin: sel ?? '0')),
          )),
          // Finalidade da operação (0 = Outras/ajuste)
          field(SetesDropdown<String>(
            label: 'forms.taxRules.purpose'.tr(),
            value: v.purpose,
            items: const ['0', '1', '2', '3', '4', '5', '6', '7'],
            itemLabel: (code) => 'forms.taxRules.purpose$code'.tr(),
            onChanged: (sel) => _emit(v.copyWith(purpose: sel ?? '0')),
          )),
          field(FocusTraversalOrder(
            order: const NumericFocusOrder(0),
            child: SetesTextField(
              label: 'forms.taxRules.ncm'.tr(),
              hint: 'forms.taxRules.wildcardHint'.tr(),
              controller: _ncm,
              focusNode: hooks.ncmFocus,
              fieldKey: hooks.ncmKey,
              keyboardType: TextInputType.number,
              validator: _ncmValidator,
              textInputAction: TextInputAction.next,
              onChanged: (t) => _emit(v.copyWith(ncm: t.trim())),
            ),
          )),
          field(FocusTraversalOrder(
            order: const NumericFocusOrder(1),
            child: SetesTextField(
              label: 'forms.taxRules.product'.tr(),
              hint: 'forms.taxRules.wildcardHint'.tr(),
              controller: _product,
              focusNode: hooks.productFocus,
              fieldKey: hooks.productKey,
              keyboardType: TextInputType.number,
              validator: _optionalIntValidator,
              textInputAction: TextInputAction.next,
              onChanged: (t) => _emit(v.copyWith(productId: t.trim())),
            ),
          )),
          field(FocusTraversalOrder(
            order: const NumericFocusOrder(2),
            child: SetesTextField(
              label: 'forms.taxRules.entity'.tr(),
              hint: 'forms.taxRules.wildcardHint'.tr(),
              controller: _entity,
              focusNode: hooks.entityFocus,
              fieldKey: hooks.entityKey,
              keyboardType: TextInputType.number,
              validator: _optionalIntValidator,
              textInputAction: TextInputAction.next,
              onChanged: (t) => _emit(v.copyWith(entityId: t.trim())),
            ),
          )),
          // UF do destinatário — vazio = coringa interestadual
          field(SetesLookupField(
            label: 'forms.taxRules.state'.tr(),
            display: v.stateId == null ? '' : v.stateName,
            onSearch: _pickState,
            onClear: v.stateId == null
                ? null
                : () => _emit(v.copyWith(
                    stateId: () => null, stateName: '')),
          )),
          field(FocusTraversalOrder(
            order: const NumericFocusOrder(3),
            child: SetesTextField(
              label: 'forms.taxRules.cfop'.tr(),
              hint: 'forms.taxRules.wildcardHint'.tr(),
              controller: _cfop,
              focusNode: hooks.cfopFocus,
              fieldKey: hooks.cfopKey,
              textInputAction: TextInputAction.done,
              onChanged: (t) => _emit(v.copyWith(cfopId: t.trim())),
            ),
          )),
          // Sentido da regra — OBRIGATÓRIO E/S, sem "Ambos" (decisão 35:
          // regra nunca vale para os dois sentidos; paridade NAT_SENTIDO).
          field(SetesDropdown<String>(
            label: 'forms.taxRules.direction'.tr(),
            value: v.direction,
            items: const ['S', 'E'],
            itemLabel: (code) => code == 'E'
                ? 'forms.taxRules.directionIn'.tr()
                : 'forms.taxRules.directionOut'.tr(),
            onChanged: (sel) =>
                _emit(v.copyWith(direction: sel ?? v.direction)),
          )),
          field(SetesRadioGroup<String>(
            label: 'forms.taxRules.finalConsumer'.tr(),
            value: v.finalConsumer,
            options: _yesNo,
            onChanged: (sel) =>
                _emit(v.copyWith(finalConsumer: sel ?? 'N')),
          )),
          field(SetesRadioGroup<String>(
            label: 'forms.taxRules.simples'.tr(),
            value: v.simples,
            options: _yesNo,
            onChanged: (sel) => _emit(v.copyWith(simples: sel ?? 'N')),
          )),
          field(SetesRadioGroup<String>(
            label: 'forms.taxRules.st'.tr(),
            value: v.st,
            options: _yesNo,
            onChanged: (sel) => _emit(v.copyWith(st: sel ?? 'N')),
          )),
        ],
      ),
    );
  }
}
