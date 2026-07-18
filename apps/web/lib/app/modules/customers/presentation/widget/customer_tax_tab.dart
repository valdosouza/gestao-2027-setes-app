import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../domain/entity/object_customer.dart';

/// Aba "Tributação" — fatia [EntityTaxData] do draft (tb_entity_tax, Fase 3
/// Rodada 4, decisões 14–17). Mesmo contrato das demais abas: recebe
/// `value` + `onChanged` e o draft vive no bloc do módulo.
///
/// Instruções de UI campo a campo: migration 006_entity_tax.sql —
/// radioboxes S/N (consumer, issRetido, issIndIncFiscal), checkboxes
/// (byPassSt, autoSendInvoice, autoSendInvoiceJustXml), dropdowns
/// canônicos (taxRegime grava o RÓTULO completo; indIeDest 1/2/9;
/// issExigibilidade 01..07).
class CustomerTaxTab extends StatefulWidget {
  const CustomerTaxTab({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final EntityTaxData value;
  final ValueChanged<EntityTaxData> onChanged;

  @override
  State<CustomerTaxTab> createState() => _CustomerTaxTabState();
}

class _CustomerTaxTabState extends State<CustomerTaxTab> {
  late final TextEditingController _issProcessNr;

  /// Valor canônico → chave i18n do rótulo exibido (o VALOR enviado é o
  /// rótulo completo — decisão 15).
  static const Map<String, String> _regimeLabels = {
    '1 - Simples Nacional': 'forms.customer.tax.regimeSimples',
    '2 - Simples Nacional - excesso de sublimite de receita bruta':
        'forms.customer.tax.regimeSimplesExcesso',
    '3 - Regime Normal - Lucro Real': 'forms.customer.tax.regimeLucroReal',
    '3 - Regime Normal - Lucro Presumido':
        'forms.customer.tax.regimeLucroPresumido',
  };

  @override
  void initState() {
    super.initState();
    _issProcessNr =
        TextEditingController(text: widget.value.issProcessNr ?? '');
  }

  @override
  void dispose() {
    _issProcessNr.dispose();
    super.dispose();
  }

  void _emit(EntityTaxData updated) => widget.onChanged(updated);

  /// Dropdown só aceita valor presente na lista — valor desconhecido
  /// (legado fora do canônico) cai para null em vez de quebrar o build.
  static T? _known<T>(T? value, List<T> domain) =>
      value != null && domain.contains(value) ? value : null;

  List<SetesRadioOption<String>> get _yesNo => [
        SetesRadioOption(value: 'S', label: 'register.yes'.tr()),
        SetesRadioOption(value: 'N', label: 'register.no'.tr()),
      ];

  @override
  Widget build(BuildContext context) {
    final v = widget.value;

    Widget field(Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 16), child: child);

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Consumidor final: radiobox Sim/Não
          field(SetesRadioGroup<String>(
            label: 'forms.customer.tax.consumer'.tr(),
            value: v.consumer,
            options: _yesNo,
            onChanged: (sel) => _emit(v.copyWith(consumer: sel ?? 'N')),
          )),
          // Regime tributário: dropdown canônico (grava o rótulo completo)
          field(SetesDropdown<String>(
            label: 'forms.customer.tax.regime'.tr(),
            value: _known(v.taxRegime, kTaxRegimes),
            items: kTaxRegimes,
            itemLabel: (regime) => _regimeLabels[regime]!.tr(),
            onChanged: (sel) => _emit(v.copyWith(taxRegime: () => sel)),
          )),
          // Ignorar ST: checkbox (fora da sequência de Tab, contrato item 8)
          // com texto explicativo (pedido do Valdo, 2026-07-18)
          ExcludeFocusTraversal(
            child: field(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SetesCheckbox(
                  label: 'forms.customer.tax.byPassSt'.tr(),
                  value: v.byPassSt,
                  onChanged: (sel) => _emit(v.copyWith(byPassSt: sel ?? false)),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: SetesText(
                    'forms.customer.tax.byPassStHelp'.tr(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            )),
          ),
          // Indicador de IE do destinatário (NFe)
          field(SetesDropdown<String>(
            label: 'forms.customer.tax.indIeDest'.tr(),
            value: _known(v.indIeDest, kIndIeDestCodes),
            items: kIndIeDestCodes,
            itemLabel: (code) => 'forms.customer.tax.indIeDest$code'.tr(),
            onChanged: (sel) => _emit(v.copyWith(indIeDest: () => sel)),
          )),
          // Exigibilidade do ISS (códigos 01..07 do legado)
          field(SetesDropdown<String>(
            label: 'forms.customer.tax.issExigibilidade'.tr(),
            value: _known(v.issExigibilidade, kIssExigibilidadeCodes),
            items: kIssExigibilidadeCodes,
            itemLabel: (code) => 'forms.customer.tax.issExig$code'.tr(),
            onChanged: (sel) =>
                _emit(v.copyWith(issExigibilidade: () => sel)),
          )),
          field(FocusTraversalOrder(
            order: const NumericFocusOrder(0),
            child: SetesTextField(
              label: 'forms.customer.tax.issProcessNr'.tr(),
              controller: _issProcessNr,
              textInputAction: TextInputAction.done,
              inputFormatters: [LengthLimitingTextInputFormatter(25)],
              onChanged: (t) =>
                  _emit(v.copyWith(issProcessNr: () => t.trim())),
            ),
          )),
          // ISS retido: radiobox Sim/Não
          field(SetesRadioGroup<String>(
            label: 'forms.customer.tax.issRetido'.tr(),
            value: v.issRetido,
            options: _yesNo,
            onChanged: (sel) => _emit(v.copyWith(issRetido: sel ?? 'N')),
          )),
          // Incentivo fiscal ISS: radiobox Sim/Não
          field(SetesRadioGroup<String>(
            label: 'forms.customer.tax.issIndIncFiscal'.tr(),
            value: v.issIndIncFiscal,
            options: _yesNo,
            onChanged: (sel) =>
                _emit(v.copyWith(issIndIncFiscal: sel ?? 'N')),
          )),
          // Checkboxes de envio (fora da sequência de Tab)
          ExcludeFocusTraversal(
            child: Column(
              children: [
                SetesCheckbox(
                  label: 'forms.customer.tax.autoSendInvoice'.tr(),
                  value: v.autoSendInvoice,
                  onChanged: (sel) =>
                      _emit(v.copyWith(autoSendInvoice: sel ?? false)),
                ),
                SetesCheckbox(
                  label: 'forms.customer.tax.autoSendInvoiceJustXml'.tr(),
                  value: v.autoSendInvoiceJustXml,
                  onChanged: (sel) => _emit(
                      v.copyWith(autoSendInvoiceJustXml: sel ?? false)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
