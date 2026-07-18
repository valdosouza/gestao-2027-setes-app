import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/lookup/datasource/carrier_lookup_datasource.dart';
import '../../../../shared/lookup/datasource/salesman_lookup_datasource.dart';
import '../../../../shared/lookup/entity/role_lookup_entity.dart';
import '../../domain/entity/object_customer.dart';

/// Aba "Cliente" — campos específicos de tb_customer (skill
/// cadastro-entidade-fiscal.md; Fase 3 Entidade Única, decisão 11).
///
/// Rodada 4 (Tributação): consumer/byPassSt saíram desta aba (foram para a
/// aba Tributação — CustomerTaxTab); creditStatus virou radiobox
/// [L]iberado/[B]loqueado e wallet virou radiobox Sim/Não (intenção — a API
/// resolve a forma de pagamento "Carteira" sozinha, decisão 18).
///
/// FKs de Vendedor/Transportadora no padrão campo-lookup-fk.md: o usuário
/// NUNCA digita id — escolhe na lista de apoio; o campo readOnly exibe o
/// nome vindo do JOIN da API (setes_central.tb_entity).
class CustomerTab extends StatefulWidget {
  const CustomerTab({
    required this.value,
    required this.onChanged,
    required this.salesmanLookup,
    required this.carrierLookup,
    super.key,
  });

  final ObjectCustomer value;
  final ValueChanged<ObjectCustomer> onChanged;
  final SalesmanLookupDatasource salesmanLookup;
  final CarrierLookupDatasource carrierLookup;

  @override
  State<CustomerTab> createState() => _CustomerTabState();
}

class _CustomerTabState extends State<CustomerTab> {
  late final TextEditingController _creditValue;
  late final TextEditingController _multiplier;

  @override
  void initState() {
    super.initState();
    final v = widget.value;
    _creditValue = TextEditingController(text: _decimalToText(v.creditValue));
    _multiplier  = TextEditingController(text: _decimalToText(v.multiplier));
  }

  @override
  void dispose() {
    for (final c in [_creditValue, _multiplier]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _decimalToText(double? value) =>
      value == null ? '' : value.toString();

  /// Aceita vírgula ou ponto; null se vazio/inválido.
  static double? _textToDecimal(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  String? _validateOptionalDecimal(String? value) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return null;
    return _textToDecimal(t) == null ? 'register.invalidNumber'.tr() : null;
  }

  void _emit(ObjectCustomer updated) => widget.onChanged(updated);

  Future<void> _pickSalesman() async {
    final picked = await showSetesLookup<RoleLookup>(
      context: context,
      title: 'lookup.salesmen'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: widget.salesmanLookup.list,
      itemId: (s) => s.id,
      itemLabel: (s) => s.name ?? '',
    );
    if (picked != null) {
      _emit(widget.value.copyWith(
        tbSalesmanId: () => picked.id,
        salesmanName: () => picked.name ?? '',
      ));
    }
  }

  Future<void> _pickCarrier() async {
    final picked = await showSetesLookup<RoleLookup>(
      context: context,
      title: 'lookup.carriers'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: widget.carrierLookup.list,
      itemId: (c) => c.id,
      itemLabel: (c) => c.name ?? '',
    );
    if (picked != null) {
      _emit(widget.value.copyWith(
        tbCarrierId: () => picked.id,
        carrierName: () => picked.name ?? '',
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tabulação (criar-formulario-cadastro.md, item 8): Tab só nos campos
    // editáveis; lookups, radios e checkboxes ficam fora da sequência.
    var order = 0;
    Widget field(Widget child) {
      final wrapped = FocusTraversalOrder(
        order: NumericFocusOrder((order++).toDouble()),
        child: child,
      );
      return Padding(padding: const EdgeInsets.only(bottom: 16), child: wrapped);
    }

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // FK Vendedor (campo-lookup-fk.md — fora do Tab por contrato)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SetesLookupField(
              label: 'forms.customer.salesman'.tr(),
              display: widget.value.salesmanName ?? '',
              onSearch: _pickSalesman,
              onClear: () => _emit(widget.value.copyWith(
                tbSalesmanId: () => null,
                salesmanName: () => null,
              )),
            ),
          ),
          // FK Transportadora
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SetesLookupField(
              label: 'forms.customer.carrier'.tr(),
              display: widget.value.carrierName ?? '',
              onSearch: _pickCarrier,
              onClear: () => _emit(widget.value.copyWith(
                tbCarrierId: () => null,
                carrierName: () => null,
              )),
            ),
          ),
          // Situação de crédito: radiobox [L]iberado / [B]loqueado
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SetesRadioGroup<String>(
              label: 'forms.customer.creditStatus'.tr(),
              value: widget.value.creditStatus,
              options: [
                SetesRadioOption(
                    value: 'L',
                    label: 'forms.customer.creditStatusReleased'.tr()),
                SetesRadioOption(
                    value: 'B',
                    label: 'forms.customer.creditStatusBlocked'.tr()),
              ],
              onChanged: (v) =>
                  _emit(widget.value.copyWith(creditStatus: v)),
            ),
          ),
          field(SetesTextField(
            label: 'forms.customer.creditValue'.tr(),
            controller: _creditValue,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            validator: _validateOptionalDecimal,
            onChanged: (t) => _emit(
                widget.value.copyWith(creditValue: () => _textToDecimal(t))),
          )),
          // Multiplicador: vazio assume 1 (DEFAULT do banco — toJson resolve)
          field(SetesTextField(
            label: 'forms.customer.multiplier'.tr(),
            controller: _multiplier,
            hint: 'forms.customer.multiplierHint'.tr(),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            validator: _validateOptionalDecimal,
            onChanged: (t) => _emit(
                widget.value.copyWith(multiplier: () => _textToDecimal(t))),
          )),
          // Carteira: intenção Sim/Não — a API resolve a forma de pagamento
          // "Carteira" (decisão 18; o app não lida com tb_payment_types_id)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SetesRadioGroup<String>(
              label: 'forms.customer.wallet'.tr(),
              value: widget.value.wallet,
              helperText: 'forms.customer.walletHelp'.tr(),
              options: [
                SetesRadioOption(value: 'S', label: 'register.yes'.tr()),
                SetesRadioOption(value: 'N', label: 'register.no'.tr()),
              ],
              onChanged: (v) =>
                  _emit(widget.value.copyWith(wallet: v ?? 'N')),
            ),
          ),
          ExcludeFocusTraversal(
            child: SetesCheckbox(
              label: 'forms.customer.active'.tr(),
              value: widget.value.active,
              onChanged: (v) =>
                  _emit(widget.value.copyWith(active: v ?? true)),
            ),
          ),
        ],
      ),
    );
  }
}
