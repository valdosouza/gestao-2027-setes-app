import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/entity/widgets/entity_date.dart';
import '../../../../shared/feedback/feedback.dart';
import '../../../../shared/feedback/form_pendency.dart';
import '../../../../shared/format/money.dart';
import '../../data/datasource/order_datasource.dart';
import '../../domain/entity/order_entity.dart';
import 'order_format.dart';

/// Dialog de CHEQUES do "Validar e Faturar" (prompt_negociacao_pedido.md
/// D5 — reflexo do legado, que abria o form do cheque POR PARCELA na
/// esteira do faturamento): para CADA parcela cuja forma é cheque
/// ([parcels] já filtradas pela página), coleta N cheques cuja soma tem
/// de ser igual ao valor da parcela — validação local (centavos) e a do
/// servidor (422 CHECK_SUM_MISMATCH). Nada é persistido aqui: o resultado
/// vai no bloco `checks` do POST /api/billing/invoice.
///
/// [initial] reabre o dialog com os cheques digitados (retorno do 422) e
/// [hint] mostra a mensagem da API no topo. [expectedAmounts] (D-N3,
/// 2026-09-07) = valor REAL da parcela na nota apontado pelo `expected` do
/// CHECK_SUM_MISMATCH, por nº de parcela: a 1ª parcela pode absorver a
/// diferença de impostos da nota (D7), então a soma dos cheques fecha
/// contra ESSE valor, não contra o negociado — sem ele o dialog travaria o
/// usuário no valor da grade. Devolve null ao cancelar.
Future<List<OrderParcelChecksInput>?> showOrderChecksDialog(
  BuildContext context, {
  required List<OrderNegotiationParcel> parcels,
  required OrderDatasource datasource,
  List<OrderParcelChecksInput> initial = const [],
  Map<int, double> expectedAmounts = const {},
  String? hint,
}) =>
    showDialog<List<OrderParcelChecksInput>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ChecksDialog(
        parcels: parcels,
        datasource: datasource,
        initial: initial,
        expectedAmounts: expectedAmounts,
        hint: hint,
      ),
    );

class _ChecksDialog extends StatefulWidget {
  const _ChecksDialog({
    required this.parcels,
    required this.datasource,
    required this.initial,
    required this.expectedAmounts,
    this.hint,
  });

  final List<OrderNegotiationParcel> parcels;
  final OrderDatasource datasource;
  final List<OrderParcelChecksInput> initial;
  final Map<int, double> expectedAmounts;
  final String? hint;

  @override
  State<_ChecksDialog> createState() => _ChecksDialogState();
}

class _ChecksDialogState extends State<_ChecksDialog> {
  /// Cheques por nº da parcela — estado LOCAL do dialog.
  final Map<int, List<OrderCheckInput>> _checks = {};

  @override
  void initState() {
    super.initState();
    for (final parcel in widget.parcels) {
      _checks[parcel.parcel] = [];
    }
    for (final entry in widget.initial) {
      if (_checks.containsKey(entry.parcel)) {
        _checks[entry.parcel] = List.of(entry.items);
      }
    }
  }

  List<OrderCheckInput> _of(OrderNegotiationParcel p) => _checks[p.parcel]!;

  double _sumOf(OrderNegotiationParcel p) =>
      _of(p).fold(0.0, (acc, c) => acc + c.value);

  /// Valor que os cheques têm de cobrir: o apontado pelo servidor
  /// (`expected`, já com a diferença da nota — D7) ou o negociado.
  double _targetOf(OrderNegotiationParcel p) =>
      widget.expectedAmounts[p.parcel] ?? p.amount;

  /// A parcela na nota difere da negociada (D7) — o dialog explicita.
  bool _hasTargetDiff(OrderNegotiationParcel p) =>
      orderCents(_targetOf(p)) != orderCents(p.amount);

  /// O que FALTA para fechar a parcela — default do valor do próximo cheque.
  double _remainingOf(OrderNegotiationParcel p) =>
      (orderCents(_targetOf(p)) - orderCents(_sumOf(p))) / 100;

  bool _matches(OrderNegotiationParcel p) =>
      orderCents(_sumOf(p)) == orderCents(_targetOf(p));

  Future<void> _addCheck(OrderNegotiationParcel p) async {
    final remaining = _remainingOf(p);
    final check = await _showCheckItemDialog(
      context,
      datasource: widget.datasource,
      suggestedValue: remaining > 0 ? remaining : null,
      suggestedDateIso: p.dueDate,
    );
    if (check == null || !mounted) return;
    setState(() => _of(p).add(check));
  }

  Future<void> _editCheck(OrderNegotiationParcel p, int index) async {
    final check = await _showCheckItemDialog(
      context,
      datasource: widget.datasource,
      existing: _of(p)[index],
    );
    if (check == null || !mounted) return;
    setState(() => _of(p)[index] = check);
  }

  /// Remoção confirmada por decisão TIPADA (R4) — o cheque digitado tem
  /// 7 campos; um clique errado não pode apagá-lo em silêncio.
  Future<void> _removeCheck(OrderNegotiationParcel p, int index) async {
    final decision = await askDecision(
      context,
      message: 'register.confirmDelete'.tr(),
      yesLabel: 'register.delete'.tr(),
    );
    if (decision != SetesDecision.yes || !mounted) return;
    setState(() => _of(p).removeAt(index));
  }

  /// UMA pendência por vez, na ordem das parcelas: ao menos um cheque e
  /// soma = valor da parcela (o servidor valida de novo).
  Future<void> _confirm() async {
    for (final p in widget.parcels) {
      if (_of(p).isEmpty) {
        await showValidationFeedback(
            context, 'forms.order.checksRequired'.tr(args: ['${p.parcel}']));
        return;
      }
      if (!_matches(p)) {
        await showValidationFeedback(
          context,
          'forms.order.checksSumMismatch'.tr(args: [
            '${p.parcel}',
            setesMoney(_sumOf(p)),
            setesMoney(_targetOf(p)),
          ]),
        );
        return;
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop([
      for (final p in widget.parcels)
        OrderParcelChecksInput(parcel: p.parcel, items: List.of(_of(p))),
    ]);
  }

  Widget _buildCheckTile(
      BuildContext context, OrderNegotiationParcel p, int index) {
    final check = _of(p)[index];
    final kindLabel = check.kind == OrderCheckKind.third
        ? 'forms.order.checkKindThird'.tr()
        : 'forms.order.checkKindOwn'.tr();
    return SetesListTile(
      leading: const Icon(Icons.receipt_outlined),
      title: SetesText('forms.order.checkRowTitle'
          .tr(args: [check.bankLabel, check.number, setesMoney(check.value)])),
      subtitle: SetesText('forms.order.checkRowSubtitle'.tr(args: [
        isoDateToDisplay(check.dtCheck),
        kindLabel,
        check.issuer,
      ])),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'forms.order.editCheck'.tr(),
            onPressed: () => _editCheck(p, index),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'forms.order.removeCheck'.tr(),
            onPressed: () => _removeCheck(p, index),
          ),
        ],
      ),
      onTap: () => _editCheck(p, index),
    );
  }

  Widget _buildParcelBlock(BuildContext context, OrderNegotiationParcel p) {
    final theme = Theme.of(context);
    final matches = _matches(p);
    final target = _targetOf(p);
    final diff = (orderCents(_sumOf(p)) - orderCents(target)) / 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SetesText(
          'forms.order.checkParcelHeader'.tr(args: [
            '${p.parcel}',
            isoDateToDisplay(p.dueDate),
            setesMoney(p.amount),
          ]),
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (p.paymentTypeDescription != null)
          SetesText(p.paymentTypeDescription!, style: theme.textTheme.bodySmall),
        if (_hasTargetDiff(p))
          SetesText(
            'forms.order.checkParcelTarget'
                .tr(args: [setesMoney(target), setesMoney(p.amount)]),
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        for (var i = 0; i < _of(p).length; i++) _buildCheckTile(context, p, i),
        const SizedBox(height: 4),
        SetesText(
          'forms.order.checksSumRow'.tr(args: [
            setesMoney(_sumOf(p)),
            setesMoney(target),
            setesMoney(diff),
          ]),
          style: matches
              ? theme.textTheme.bodyMedium
              : theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error, fontWeight: FontWeight.w600),
        ),
        SetesButton(
          label: 'forms.order.addCheck'.tr(),
          kind: SetesButtonKind.text,
          icon: Icons.add,
          onPressed: () => _addCheck(p),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: SetesText('forms.order.checksTitle'.tr()),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SetesText('forms.order.checksHint'.tr(),
                  style: theme.textTheme.bodySmall),
              if (widget.hint != null) ...[
                const SizedBox(height: 8),
                SetesText(
                  widget.hint!,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.error),
                ),
                SetesText('forms.order.checksAdjustHint'.tr(),
                    style: theme.textTheme.bodySmall),
              ],
              for (final p in widget.parcels) ...[
                const Divider(height: 24),
                _buildParcelBlock(context, p),
              ],
            ],
          ),
        ),
      ),
      actions: [
        SetesButton(
          label: 'register.cancel'.tr(),
          kind: SetesButtonKind.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
        SetesButton(
          label: 'forms.order.confirmInvoice'.tr(),
          kind: SetesButtonKind.text,
          onPressed: _confirm,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// UM cheque (sub-dialog)
// ---------------------------------------------------------------------

Future<OrderCheckInput?> _showCheckItemDialog(
  BuildContext context, {
  required OrderDatasource datasource,
  OrderCheckInput? existing,
  double? suggestedValue,
  String? suggestedDateIso,
}) =>
    showDialog<OrderCheckInput>(
      context: context,
      builder: (_) => _CheckItemDialog(
        datasource: datasource,
        existing: existing,
        suggestedValue: suggestedValue,
        suggestedDateIso: suggestedDateIso,
      ),
    );

/// Form de UM cheque: banco (lookup do catálogo via /api/orders/banks-
/// lookup), agência, conta, número, emitente, valor, "bom para" (texto +
/// calendário) e tipo Próprio/Terceiro. Limites = DTO do servidor
/// (agency 10, account 15, number 20, issuer 100, valor > 0 com 2 casas).
class _CheckItemDialog extends StatefulWidget {
  const _CheckItemDialog({
    required this.datasource,
    this.existing,
    this.suggestedValue,
    this.suggestedDateIso,
  });

  final OrderDatasource datasource;
  final OrderCheckInput? existing;
  final double? suggestedValue;
  final String? suggestedDateIso;

  @override
  State<_CheckItemDialog> createState() => _CheckItemDialogState();
}

class _CheckItemDialogState extends State<_CheckItemDialog> {
  late final TextEditingController _agency;
  late final TextEditingController _account;
  late final TextEditingController _number;
  late final TextEditingController _issuer;
  late final TextEditingController _value;
  late final TextEditingController _dtCheck;
  final _agencyFocus = FocusNode();
  final _accountFocus = FocusNode();
  final _numberFocus = FocusNode();
  final _issuerFocus = FocusNode();
  final _valueFocus = FocusNode();
  final _dtCheckFocus = FocusNode();
  final _agencyKey = GlobalKey<FormFieldState<String>>();
  final _accountKey = GlobalKey<FormFieldState<String>>();
  final _numberKey = GlobalKey<FormFieldState<String>>();
  final _issuerKey = GlobalKey<FormFieldState<String>>();
  final _valueKey = GlobalKey<FormFieldState<String>>();
  final _dtCheckKey = GlobalKey<FormFieldState<String>>();

  /// Achado do passeio logado nº 2 (o mesmo da seção de negociação): a
  /// marca da pendência local só sumia no próximo Salvar. Revalida SÓ
  /// enquanto há erro — some ao corrigir, sem validar ao vivo.
  void _revalidateIfMarked(GlobalKey<FormFieldState<String>> key) {
    final state = key.currentState;
    if (state != null && state.hasError) state.validate();
  }

  int?   _bankId;
  String _bankLabel = '';
  String _kind = OrderCheckKind.own;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _bankId    = existing?.bankId;
    _bankLabel = existing?.bankLabel ?? '';
    _kind      = existing?.kind ?? OrderCheckKind.own;
    _agency  = TextEditingController(text: existing?.agency ?? '');
    _account = TextEditingController(text: existing?.account ?? '');
    _number  = TextEditingController(text: existing?.number ?? '');
    _issuer  = TextEditingController(text: existing?.issuer ?? '');
    final value = existing?.value ?? widget.suggestedValue;
    _value = TextEditingController(
        text: value == null || value <= 0 ? '' : orderDecimalText(value));
    _dtCheck = TextEditingController(
        text: isoDateToDisplay(
            existing?.dtCheck ?? widget.suggestedDateIso ?? orderTodayIso()));
  }

  @override
  void dispose() {
    _agency.dispose();
    _account.dispose();
    _number.dispose();
    _issuer.dispose();
    _value.dispose();
    _dtCheck.dispose();
    _agencyFocus.dispose();
    _accountFocus.dispose();
    _numberFocus.dispose();
    _issuerFocus.dispose();
    _valueFocus.dispose();
    _dtCheckFocus.dispose();
    super.dispose();
  }

  Future<void> _pickBank() async {
    final picked = await showSetesLookup<OrderBankLookup>(
      context: context,
      title: 'lookup.banks'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: widget.datasource.banksLookup,
      itemId: (b) => b.id,
      itemLabel: (b) => b.display,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _bankId    = picked.id;
      _bankLabel = picked.display;
    });
  }

  Future<void> _pickDate() async {
    final currentIso = displayDateToIso(_dtCheck.text);
    final picked = await showDatePicker(
      context: context,
      initialDate:
          currentIso == null ? DateTime.now() : DateTime.parse(currentIso),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => _dtCheck.text = isoDateToDisplay(orderIsoDate(picked)));
  }

  /// Obrigatório + tamanho máximo (regra do DTO do servidor).
  String? _validateText(String? value, String labelKey, int max) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'register.requiredField'.tr(args: [labelKey.tr()]);
    }
    if (text.length > max) {
      return 'forms.order.checkTooLong'.tr(args: [labelKey.tr(), '$max']);
    }
    return null;
  }

  String? _validateValue(String? value) {
    final amount = orderParseDecimal(value ?? '');
    return (amount == null || amount <= 0 || !orderHasTwoDecimals(amount))
        ? 'forms.order.checkValueInvalid'
        : null;
  }

  String? _validateDate(String? value) =>
      displayDateToIso(value ?? '') == null ? 'register.invalidDate' : null;

  Future<void> _confirm() async {
    final ok = await ensureNoPendency(context, [
      PendencyField(
        name: 'bankId',
        validate: () =>
            _bankId == null ? 'forms.order.checkBankRequired' : null,
      ),
      PendencyField(
        name: 'agency',
        validate: () =>
            _validateText(_agency.text, 'forms.order.checkAgency', 10),
        focusNode: _agencyFocus,
        fieldKey: _agencyKey,
      ),
      PendencyField(
        name: 'account',
        validate: () =>
            _validateText(_account.text, 'forms.order.checkAccount', 15),
        focusNode: _accountFocus,
        fieldKey: _accountKey,
      ),
      PendencyField(
        name: 'number',
        validate: () =>
            _validateText(_number.text, 'forms.order.checkNumber', 20),
        focusNode: _numberFocus,
        fieldKey: _numberKey,
      ),
      PendencyField(
        name: 'issuer',
        validate: () =>
            _validateText(_issuer.text, 'forms.order.checkIssuer', 100),
        focusNode: _issuerFocus,
        fieldKey: _issuerKey,
      ),
      PendencyField(
        name: 'value',
        validate: () => _validateValue(_value.text),
        focusNode: _valueFocus,
        fieldKey: _valueKey,
      ),
      PendencyField(
        name: 'dtCheck',
        validate: () => _validateDate(_dtCheck.text),
        focusNode: _dtCheckFocus,
        fieldKey: _dtCheckKey,
      ),
    ]);
    if (!ok || !mounted) return;
    Navigator.of(context).pop(OrderCheckInput(
      bankId:    _bankId!,
      bankLabel: _bankLabel,
      agency:    _agency.text.trim(),
      account:   _account.text.trim(),
      number:    _number.text.trim(),
      issuer:    _issuer.text.trim(),
      value:     orderParseDecimal(_value.text)!,
      dtCheck:   displayDateToIso(_dtCheck.text)!,
      kind:      _kind,
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: SetesText(_editing
            ? 'forms.order.editCheck'.tr()
            : 'forms.order.addCheck'.tr()),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SetesLookupField(
                  label: 'forms.order.checkBank'.tr(),
                  display: _bankLabel,
                  onSearch: _pickBank,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SetesTextField(
                        label: 'forms.order.checkAgency'.tr(),
                        controller: _agency,
                        focusNode: _agencyFocus,
                        fieldKey: _agencyKey,
                        autofocus: true,
                        textInputAction: TextInputAction.next,
                        validator: (value) => _validateText(
                            value, 'forms.order.checkAgency', 10),
                        onChanged: (_) => _revalidateIfMarked(_agencyKey),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SetesTextField(
                        label: 'forms.order.checkAccount'.tr(),
                        controller: _account,
                        focusNode: _accountFocus,
                        fieldKey: _accountKey,
                        textInputAction: TextInputAction.next,
                        validator: (value) => _validateText(
                            value, 'forms.order.checkAccount', 15),
                        onChanged: (_) => _revalidateIfMarked(_accountKey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SetesTextField(
                  label: 'forms.order.checkNumber'.tr(),
                  controller: _number,
                  focusNode: _numberFocus,
                  fieldKey: _numberKey,
                  textInputAction: TextInputAction.next,
                  validator: (value) =>
                      _validateText(value, 'forms.order.checkNumber', 20),
                  onChanged: (_) => _revalidateIfMarked(_numberKey),
                ),
                const SizedBox(height: 12),
                SetesTextField(
                  label: 'forms.order.checkIssuer'.tr(),
                  controller: _issuer,
                  focusNode: _issuerFocus,
                  fieldKey: _issuerKey,
                  textInputAction: TextInputAction.next,
                  validator: (value) =>
                      _validateText(value, 'forms.order.checkIssuer', 100),
                  onChanged: (_) => _revalidateIfMarked(_issuerKey),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SetesTextField(
                        label: 'forms.order.checkValue'.tr(),
                        controller: _value,
                        focusNode: _valueFocus,
                        fieldKey: _valueKey,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textInputAction: TextInputAction.next,
                        validator: (value) => _validateValue(value)?.tr(),
                        onChanged: (_) => _revalidateIfMarked(_valueKey),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SetesTextField(
                        label: 'forms.order.checkDate'.tr(),
                        hint: 'register.dateHint'.tr(),
                        controller: _dtCheck,
                        focusNode: _dtCheckFocus,
                        fieldKey: _dtCheckKey,
                        keyboardType: TextInputType.datetime,
                        textInputAction: TextInputAction.done,
                        suffixIcon: Icons.calendar_today_outlined,
                        onSuffixPressed: _pickDate,
                        validator: (value) => _validateDate(value)?.tr(),
                        onChanged: (_) => _revalidateIfMarked(_dtCheckKey),
                        onSubmitted: (_) => _confirm(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SetesRadioGroup<String>(
                  label: 'forms.order.checkKindLabel'.tr(),
                  value: _kind,
                  options: [
                    SetesRadioOption(
                        value: OrderCheckKind.own,
                        label: 'forms.order.checkKindOwn'.tr()),
                    SetesRadioOption(
                        value: OrderCheckKind.third,
                        label: 'forms.order.checkKindThird'.tr()),
                  ],
                  onChanged: (kind) =>
                      setState(() => _kind = kind ?? OrderCheckKind.own),
                ),
              ],
            ),
          ),
        ),
        actions: [
          SetesButton(
            label: 'register.cancel'.tr(),
            kind: SetesButtonKind.text,
            onPressed: () => Navigator.of(context).pop(),
          ),
          SetesButton(
            label: 'register.save'.tr(),
            kind: SetesButtonKind.text,
            onPressed: _confirm,
          ),
        ],
      );
}
