import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/entity/widgets/entity_date.dart';
import '../../../../shared/feedback/form_pendency.dart';
import '../../../../shared/format/money.dart';
import '../../data/datasource/check_lookup_datasource.dart';
import '../../domain/entity/check_entity.dart';
import 'check_format.dart';

/// Dialogs de ação da tela de Cheques — mesmo padrão dos dialogs do
/// bank_slip_detail_view.dart / bank_slip_issue_dialog.dart: cada um
/// valida com [PendencyField]/[ensureNoPendency] (R3 — uma pendência por
/// vez) e devolve o payload pronto pelo Navigator.pop; quem EXECUTA a ação
/// é o bloc (evento correspondente disparado pela page/detail view).

// -----------------------------------------------------------------------
// Lookups compartilhados entre os dialogs
// -----------------------------------------------------------------------

/// Rótulo da conta: "Caixa" (id 0, fixo pela TELA — não vem da API) ou o
/// `label` já composto pela API.
String checkAccountLabel(CheckBankAccountLookup account) =>
    account.id == 0 ? 'forms.checks.cash'.tr() : account.label;

/// Lookup de conta bancária — [allowCash] adiciona a opção Caixa (id 0) na
/// frente da lista quando o DTO da ação aceita bankAccountId 0 (molde
/// settlements._pickAccount).
Future<CheckBankAccountLookup?> pickCheckBankAccount(
  BuildContext context,
  CheckLookupDatasource lookup, {
  required bool allowCash,
}) {
  List<CheckBankAccountLookup>? cache;
  return showSetesLookup<CheckBankAccountLookup>(
    context: context,
    title: 'lookup.bankAccounts'.tr(),
    filterHint: 'register.filterHint'.tr(),
    emptyText: 'register.emptyList'.tr(),
    onSearch: (filter) async {
      cache ??= await lookup.bankAccounts('');
      final lower = filter.toLowerCase();
      return [
        if (allowCash) const CheckBankAccountLookup(id: 0),
        for (final account in cache!)
          if (lower.isEmpty ||
              checkAccountLabel(account).toLowerCase().contains(lower))
            account,
      ];
    },
    itemId: (a) => a.id,
    itemLabel: checkAccountLabel,
  );
}

Future<CheckProviderLookup?> _pickProvider(
        BuildContext context, CheckLookupDatasource lookup) =>
    showSetesLookup<CheckProviderLookup>(
      context: context,
      title: 'lookup.providers'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: lookup.providers,
      itemId: (p) => p.id,
      itemLabel: (p) => p.name,
    );

String _payableLabel(CheckOpenPayable p) => [
      if (p.number != null && p.number!.isNotEmpty)
        'forms.checks.titleNumberRow'.tr(args: [p.number!]),
      if (p.entityName != null && p.entityName!.isNotEmpty) p.entityName!,
      'forms.checks.balanceRow'.tr(args: [setesMoney(p.balance)]),
    ].join(' · ');

Future<CheckOpenPayable?> _pickOpenPayable(
        BuildContext context, CheckLookupDatasource lookup) =>
    showSetesLookup<CheckOpenPayable>(
      context: context,
      title: 'lookup.openPayables'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: lookup.openPayables,
      itemId: (p) => p.orderId,
      itemLabel: _payableLabel,
    );

// -----------------------------------------------------------------------
// 1) Depositar (evento B) — dtRecord + bankAccountId (sem Caixa: DTO exige
//    conta > 0, o cofre vai para um BANCO)
// -----------------------------------------------------------------------

class _DepositDialog extends StatefulWidget {
  const _DepositDialog({required this.check, required this.lookup});

  final CheckFull check;
  final CheckLookupDatasource lookup;

  @override
  State<_DepositDialog> createState() => _DepositDialogState();
}

class _DepositDialogState extends State<_DepositDialog> {
  late final TextEditingController _dtRecord;
  final _dtFocus = FocusNode();
  final _dtKey = GlobalKey<FormFieldState<String>>();
  CheckBankAccountLookup? _account;

  @override
  void initState() {
    super.initState();
    _dtRecord = TextEditingController(text: isoDateToDisplay(checksTodayIso()));
  }

  @override
  void dispose() {
    _dtRecord.dispose();
    _dtFocus.dispose();
    super.dispose();
  }

  String? _validateDate() =>
      displayDateToIso(_dtRecord.text) == null ? 'register.invalidDate' : null;

  String? _validateAccount() =>
      _account == null ? 'forms.checks.bankAccountRequired' : null;

  Future<void> _pickAccount() async {
    final picked =
        await pickCheckBankAccount(context, widget.lookup, allowCash: false);
    if (picked != null && mounted) setState(() => _account = picked);
  }

  Future<void> _confirm() async {
    final ok = await ensureNoPendency(context, [
      PendencyField(
          name: 'dtRecord',
          validate: _validateDate,
          focusNode: _dtFocus,
          fieldKey: _dtKey),
      PendencyField(name: 'bankAccountId', validate: _validateAccount),
    ]);
    if (!ok || !mounted) return;
    Navigator.of(context)
        .pop((displayDateToIso(_dtRecord.text)!, _account!.id));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: SetesText('forms.checks.depositTitle'.tr()),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SetesText('forms.checks.depositHint'
                  .tr(args: [widget.check.number])),
              const SizedBox(height: 16),
              SetesTextField(
                label: 'forms.checks.dtRecord'.tr(),
                hint: 'register.dateHint'.tr(),
                controller: _dtRecord,
                focusNode: _dtFocus,
                fieldKey: _dtKey,
                autofocus: true,
                validator: (_) => _validateDate()?.tr(),
              ),
              const SizedBox(height: 12),
              SetesLookupField(
                label: 'forms.checks.bankAccount'.tr(),
                display: _account == null ? '' : checkAccountLabel(_account!),
                validatorMessage: 'register.required'.tr(),
                onSearch: _pickAccount,
              ),
            ],
          ),
        ),
        actions: [
          SetesButton(
            label: 'register.cancel'.tr(),
            kind: SetesButtonKind.text,
            onPressed: () => Navigator.of(context).pop(),
          ),
          SetesButton(
            label: 'forms.checks.confirmDeposit'.tr(),
            kind: SetesButtonKind.text,
            onPressed: _confirm,
          ),
        ],
      );
}

/// Abre o dialog DEPOSITAR — devolve (dtRecord ISO, bankAccountId).
Future<(String, int)?> showCheckDepositDialog(
        BuildContext context, CheckFull check, CheckLookupDatasource lookup) =>
    showDialog<(String, int)>(
      context: context,
      builder: (_) => _DepositDialog(check: check, lookup: lookup),
    );

// -----------------------------------------------------------------------
// 2) Descontar na factoring (evento D) — dtRecord + factoringEntityId +
//    bankAccountId (Caixa permitido) + feeValue (default 0, digitado)
// -----------------------------------------------------------------------

class CheckDiscountInput {
  const CheckDiscountInput({
    required this.dtRecord,
    required this.factoringEntityId,
    required this.bankAccountId,
    required this.feeValue,
  });

  final String dtRecord;
  final int factoringEntityId;
  final int bankAccountId;
  final double feeValue;
}

class _DiscountDialog extends StatefulWidget {
  const _DiscountDialog({required this.check, required this.lookup});

  final CheckFull check;
  final CheckLookupDatasource lookup;

  @override
  State<_DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<_DiscountDialog> {
  late final TextEditingController _dtRecord;
  late final TextEditingController _feeValue;
  final _dtFocus = FocusNode();
  final _dtKey = GlobalKey<FormFieldState<String>>();
  final _feeFocus = FocusNode();
  final _feeKey = GlobalKey<FormFieldState<String>>();
  CheckProviderLookup? _factoring;
  CheckBankAccountLookup? _account;

  @override
  void initState() {
    super.initState();
    _dtRecord = TextEditingController(text: isoDateToDisplay(checksTodayIso()));
    _feeValue = TextEditingController(text: checksDecimalText(0));
  }

  @override
  void dispose() {
    _dtRecord.dispose();
    _feeValue.dispose();
    _dtFocus.dispose();
    _feeFocus.dispose();
    super.dispose();
  }

  String? _validateDate() =>
      displayDateToIso(_dtRecord.text) == null ? 'register.invalidDate' : null;

  String? _validateFactoring() =>
      _factoring == null ? 'forms.checks.factoringRequired' : null;

  String? _validateAccount() =>
      _account == null ? 'forms.checks.bankAccountRequired' : null;

  String? _validateFee() {
    final value = checksParseDecimal(_feeValue.text);
    return (value == null || value < 0) ? 'forms.checks.feeValueInvalid' : null;
  }

  Future<void> _pickFactoring() async {
    final picked = await _pickProvider(context, widget.lookup);
    if (picked != null && mounted) setState(() => _factoring = picked);
  }

  Future<void> _pickAccount() async {
    final picked =
        await pickCheckBankAccount(context, widget.lookup, allowCash: true);
    if (picked != null && mounted) setState(() => _account = picked);
  }

  Future<void> _confirm() async {
    final ok = await ensureNoPendency(context, [
      PendencyField(
          name: 'dtRecord',
          validate: _validateDate,
          focusNode: _dtFocus,
          fieldKey: _dtKey),
      PendencyField(name: 'factoringEntityId', validate: _validateFactoring),
      PendencyField(name: 'bankAccountId', validate: _validateAccount),
      PendencyField(
          name: 'feeValue',
          validate: _validateFee,
          focusNode: _feeFocus,
          fieldKey: _feeKey),
    ]);
    if (!ok || !mounted) return;
    Navigator.of(context).pop(CheckDiscountInput(
      dtRecord: displayDateToIso(_dtRecord.text)!,
      factoringEntityId: _factoring!.id,
      bankAccountId: _account!.id,
      feeValue: checksParseDecimal(_feeValue.text) ?? 0,
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: SetesText('forms.checks.discountTitle'.tr()),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SetesText('forms.checks.discountHint'
                  .tr(args: [widget.check.number])),
              const SizedBox(height: 16),
              SetesTextField(
                label: 'forms.checks.dtRecord'.tr(),
                hint: 'register.dateHint'.tr(),
                controller: _dtRecord,
                focusNode: _dtFocus,
                fieldKey: _dtKey,
                autofocus: true,
                validator: (_) => _validateDate()?.tr(),
              ),
              const SizedBox(height: 12),
              SetesLookupField(
                label: 'forms.checks.factoringEntity'.tr(),
                display: _factoring?.name ?? '',
                validatorMessage: 'register.required'.tr(),
                onSearch: _pickFactoring,
              ),
              const SizedBox(height: 12),
              SetesLookupField(
                label: 'forms.checks.bankAccount'.tr(),
                display: _account == null ? '' : checkAccountLabel(_account!),
                validatorMessage: 'register.required'.tr(),
                onSearch: _pickAccount,
              ),
              const SizedBox(height: 12),
              SetesTextField(
                label: 'forms.checks.feeValue'.tr(),
                controller: _feeValue,
                focusNode: _feeFocus,
                fieldKey: _feeKey,
                keyboardType: TextInputType.number,
                validator: (_) => _validateFee()?.tr(),
                onSubmitted: (_) => _confirm(),
              ),
            ],
          ),
        ),
        actions: [
          SetesButton(
            label: 'register.cancel'.tr(),
            kind: SetesButtonKind.text,
            onPressed: () => Navigator.of(context).pop(),
          ),
          SetesButton(
            label: 'forms.checks.confirmDiscount'.tr(),
            kind: SetesButtonKind.text,
            onPressed: _confirm,
          ),
        ],
      );
}

Future<CheckDiscountInput?> showCheckDiscountDialog(
        BuildContext context, CheckFull check, CheckLookupDatasource lookup) =>
    showDialog<CheckDiscountInput>(
      context: context,
      builder: (_) => _DiscountDialog(check: check, lookup: lookup),
    );

// -----------------------------------------------------------------------
// 3) Retorno com reembolso (evento T) — dtRecord + bankAccountId (Caixa
//    permitido: o dinheiro sai da empresa de volta para a factoring)
// -----------------------------------------------------------------------

class _ReturnRefundDialog extends StatefulWidget {
  const _ReturnRefundDialog({required this.check, required this.lookup});

  final CheckFull check;
  final CheckLookupDatasource lookup;

  @override
  State<_ReturnRefundDialog> createState() => _ReturnRefundDialogState();
}

class _ReturnRefundDialogState extends State<_ReturnRefundDialog> {
  late final TextEditingController _dtRecord;
  final _dtFocus = FocusNode();
  final _dtKey = GlobalKey<FormFieldState<String>>();
  CheckBankAccountLookup? _account;

  @override
  void initState() {
    super.initState();
    _dtRecord = TextEditingController(text: isoDateToDisplay(checksTodayIso()));
  }

  @override
  void dispose() {
    _dtRecord.dispose();
    _dtFocus.dispose();
    super.dispose();
  }

  String? _validateDate() =>
      displayDateToIso(_dtRecord.text) == null ? 'register.invalidDate' : null;

  String? _validateAccount() =>
      _account == null ? 'forms.checks.bankAccountRequired' : null;

  Future<void> _pickAccount() async {
    final picked =
        await pickCheckBankAccount(context, widget.lookup, allowCash: true);
    if (picked != null && mounted) setState(() => _account = picked);
  }

  Future<void> _confirm() async {
    final ok = await ensureNoPendency(context, [
      PendencyField(
          name: 'dtRecord',
          validate: _validateDate,
          focusNode: _dtFocus,
          fieldKey: _dtKey),
      PendencyField(name: 'bankAccountId', validate: _validateAccount),
    ]);
    if (!ok || !mounted) return;
    Navigator.of(context)
        .pop((displayDateToIso(_dtRecord.text)!, _account!.id));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: SetesText('forms.checks.returnRefundTitle'.tr()),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SetesText('forms.checks.returnRefundHint'
                  .tr(args: [widget.check.number])),
              const SizedBox(height: 16),
              SetesTextField(
                label: 'forms.checks.dtRecord'.tr(),
                hint: 'register.dateHint'.tr(),
                controller: _dtRecord,
                focusNode: _dtFocus,
                fieldKey: _dtKey,
                autofocus: true,
                validator: (_) => _validateDate()?.tr(),
              ),
              const SizedBox(height: 12),
              SetesLookupField(
                label: 'forms.checks.bankAccount'.tr(),
                display: _account == null ? '' : checkAccountLabel(_account!),
                validatorMessage: 'register.required'.tr(),
                onSearch: _pickAccount,
              ),
            ],
          ),
        ),
        actions: [
          SetesButton(
            label: 'register.cancel'.tr(),
            kind: SetesButtonKind.text,
            onPressed: () => Navigator.of(context).pop(),
          ),
          SetesButton(
            label: 'forms.checks.confirmReturnRefund'.tr(),
            kind: SetesButtonKind.text,
            onPressed: _confirm,
          ),
        ],
      );
}

/// Abre o dialog RETORNO COM REEMBOLSO — devolve (dtRecord ISO, bankAccountId).
Future<(String, int)?> showCheckReturnRefundDialog(
        BuildContext context, CheckFull check, CheckLookupDatasource lookup) =>
    showDialog<(String, int)>(
      context: context,
      builder: (_) => _ReturnRefundDialog(check: check, lookup: lookup),
    );

// -----------------------------------------------------------------------
// 4) Retorno bom (evento F) — SEM movimento; só nota opcional
// -----------------------------------------------------------------------

/// Resultado da confirmação (nota OPCIONAL, null permitido) — distingue
/// "confirmou sem observação" (null aqui) de "cancelou o dialog" (o
/// próprio Future do showDialog vem null nesse caso).
class CheckReturnGoodResult {
  const CheckReturnGoodResult(this.note);
  final String? note;
}

class _ReturnGoodDialog extends StatefulWidget {
  const _ReturnGoodDialog({required this.check});

  final CheckFull check;

  @override
  State<_ReturnGoodDialog> createState() => _ReturnGoodDialogState();
}

class _ReturnGoodDialogState extends State<_ReturnGoodDialog> {
  final _note = TextEditingController();
  final _noteFocus = FocusNode();
  final _noteKey = GlobalKey<FormFieldState<String>>();

  @override
  void dispose() {
    _note.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  String? _validateNote() =>
      _note.text.trim().length > 255 ? 'forms.checks.noteTooLong' : null;

  Future<void> _confirm() async {
    final ok = await ensureNoPendency(context, [
      PendencyField(
          name: 'note',
          validate: _validateNote,
          focusNode: _noteFocus,
          fieldKey: _noteKey),
    ]);
    if (!ok || !mounted) return;
    final note = _note.text.trim();
    Navigator.of(context).pop(CheckReturnGoodResult(note.isEmpty ? null : note));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: SetesText('forms.checks.returnGoodTitle'.tr()),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SetesText('forms.checks.returnGoodConfirm'
                  .tr(args: [widget.check.number])),
              const SizedBox(height: 16),
              SetesTextField(
                label: 'forms.checks.note'.tr(),
                controller: _note,
                focusNode: _noteFocus,
                fieldKey: _noteKey,
                autofocus: true,
                validator: (_) => _validateNote()?.tr(),
                onSubmitted: (_) => _confirm(),
              ),
            ],
          ),
        ),
        actions: [
          SetesButton(
            label: 'register.cancel'.tr(),
            kind: SetesButtonKind.text,
            onPressed: () => Navigator.of(context).pop(),
          ),
          SetesButton(
            label: 'forms.checks.confirmReturnGood'.tr(),
            kind: SetesButtonKind.text,
            onPressed: _confirm,
          ),
        ],
      );
}

/// Abre o dialog RETORNO BOM — null = CANCELOU o dialog; um
/// [CheckReturnGoodResult] (mesmo com note null) = CONFIRMOU.
Future<CheckReturnGoodResult?> showCheckReturnGoodDialog(
        BuildContext context, CheckFull check) =>
    showDialog<CheckReturnGoodResult>(
      context: context,
      builder: (_) => _ReturnGoodDialog(check: check),
    );

// -----------------------------------------------------------------------
// 5) Usar em pagamento (evento P) — escolhe um título a pagar aberto
// -----------------------------------------------------------------------

class CheckPayInput {
  const CheckPayInput(
      {required this.dtRecord, required this.orderId, required this.parcel});

  final String dtRecord;
  final int orderId;
  final int parcel;
}

class _PayDialog extends StatefulWidget {
  const _PayDialog({required this.check, required this.lookup});

  final CheckFull check;
  final CheckLookupDatasource lookup;

  @override
  State<_PayDialog> createState() => _PayDialogState();
}

class _PayDialogState extends State<_PayDialog> {
  late final TextEditingController _dtRecord;
  final _dtFocus = FocusNode();
  final _dtKey = GlobalKey<FormFieldState<String>>();
  CheckOpenPayable? _payable;

  @override
  void initState() {
    super.initState();
    _dtRecord = TextEditingController(text: isoDateToDisplay(checksTodayIso()));
  }

  @override
  void dispose() {
    _dtRecord.dispose();
    _dtFocus.dispose();
    super.dispose();
  }

  String? _validateDate() =>
      displayDateToIso(_dtRecord.text) == null ? 'register.invalidDate' : null;

  String? _validatePayable() =>
      _payable == null ? 'forms.checks.openPayableRequired' : null;

  Future<void> _pickPayable() async {
    final picked = await _pickOpenPayable(context, widget.lookup);
    if (picked != null && mounted) setState(() => _payable = picked);
  }

  Future<void> _confirm() async {
    final ok = await ensureNoPendency(context, [
      PendencyField(
          name: 'dtRecord',
          validate: _validateDate,
          focusNode: _dtFocus,
          fieldKey: _dtKey),
      PendencyField(name: 'orderId', validate: _validatePayable),
    ]);
    if (!ok || !mounted) return;
    Navigator.of(context).pop(CheckPayInput(
      dtRecord: displayDateToIso(_dtRecord.text)!,
      orderId: _payable!.orderId,
      parcel: _payable!.parcel,
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: SetesText('forms.checks.payTitle'.tr()),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SetesText('forms.checks.payHint'
                  .tr(args: [widget.check.number, setesMoney(widget.check.value)])),
              const SizedBox(height: 16),
              SetesLookupField(
                label: 'forms.checks.openPayable'.tr(),
                display: _payable == null ? '' : _payableLabel(_payable!),
                validatorMessage: 'register.required'.tr(),
                onSearch: _pickPayable,
              ),
              const SizedBox(height: 12),
              SetesTextField(
                label: 'forms.checks.dtRecord'.tr(),
                hint: 'register.dateHint'.tr(),
                controller: _dtRecord,
                focusNode: _dtFocus,
                fieldKey: _dtKey,
                validator: (_) => _validateDate()?.tr(),
                onSubmitted: (_) => _confirm(),
              ),
            ],
          ),
        ),
        actions: [
          SetesButton(
            label: 'register.cancel'.tr(),
            kind: SetesButtonKind.text,
            onPressed: () => Navigator.of(context).pop(),
          ),
          SetesButton(
            label: 'forms.checks.confirmPay'.tr(),
            kind: SetesButtonKind.text,
            onPressed: _confirm,
          ),
        ],
      );
}

Future<CheckPayInput?> showCheckPayDialog(
        BuildContext context, CheckFull check, CheckLookupDatasource lookup) =>
    showDialog<CheckPayInput>(
      context: context,
      builder: (_) => _PayDialog(check: check, lookup: lookup),
    );

// -----------------------------------------------------------------------
// 6) Devolver — sem fundos (evento V) — cria título novo contra a origem
// -----------------------------------------------------------------------

class CheckReturnInput {
  const CheckReturnInput({required this.dtRecord, this.note});

  final String dtRecord;
  final String? note;
}

class _ReturnDialog extends StatefulWidget {
  const _ReturnDialog({required this.check});

  final CheckFull check;

  @override
  State<_ReturnDialog> createState() => _ReturnDialogState();
}

class _ReturnDialogState extends State<_ReturnDialog> {
  late final TextEditingController _dtRecord;
  final _dtFocus = FocusNode();
  final _dtKey = GlobalKey<FormFieldState<String>>();
  final _note = TextEditingController();
  final _noteFocus = FocusNode();
  final _noteKey = GlobalKey<FormFieldState<String>>();

  @override
  void initState() {
    super.initState();
    _dtRecord = TextEditingController(text: isoDateToDisplay(checksTodayIso()));
  }

  @override
  void dispose() {
    _dtRecord.dispose();
    _dtFocus.dispose();
    _note.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  String? _validateDate() =>
      displayDateToIso(_dtRecord.text) == null ? 'register.invalidDate' : null;

  String? _validateNote() =>
      _note.text.trim().length > 255 ? 'forms.checks.noteTooLong' : null;

  Future<void> _confirm() async {
    final ok = await ensureNoPendency(context, [
      PendencyField(
          name: 'dtRecord',
          validate: _validateDate,
          focusNode: _dtFocus,
          fieldKey: _dtKey),
      PendencyField(
          name: 'note',
          validate: _validateNote,
          focusNode: _noteFocus,
          fieldKey: _noteKey),
    ]);
    if (!ok || !mounted) return;
    final note = _note.text.trim();
    Navigator.of(context).pop(CheckReturnInput(
      dtRecord: displayDateToIso(_dtRecord.text)!,
      note: note.isEmpty ? null : note,
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: SetesText('forms.checks.returnTitle'.tr()),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SetesText('forms.checks.returnConfirm'
                  .tr(args: [widget.check.number, widget.check.entityName ?? ''])),
              const SizedBox(height: 16),
              SetesTextField(
                label: 'forms.checks.dtRecord'.tr(),
                hint: 'register.dateHint'.tr(),
                controller: _dtRecord,
                focusNode: _dtFocus,
                fieldKey: _dtKey,
                autofocus: true,
                validator: (_) => _validateDate()?.tr(),
              ),
              const SizedBox(height: 12),
              SetesTextField(
                label: 'forms.checks.note'.tr(),
                controller: _note,
                focusNode: _noteFocus,
                fieldKey: _noteKey,
                validator: (_) => _validateNote()?.tr(),
                onSubmitted: (_) => _confirm(),
              ),
            ],
          ),
        ),
        actions: [
          SetesButton(
            label: 'register.cancel'.tr(),
            kind: SetesButtonKind.text,
            onPressed: () => Navigator.of(context).pop(),
          ),
          SetesButton(
            label: 'forms.checks.confirmReturn'.tr(),
            kind: SetesButtonKind.text,
            onPressed: _confirm,
          ),
        ],
      );
}

Future<CheckReturnInput?> showCheckReturnDialog(
        BuildContext context, CheckFull check) =>
    showDialog<CheckReturnInput>(
      context: context,
      builder: (_) => _ReturnDialog(check: check),
    );

// -----------------------------------------------------------------------
// 7) Estornar o último evento (evento X) — motivo obrigatório; o Nº do
//    evento é SEMPRE o mais recente (D10) — a tela nunca deixa escolher
// -----------------------------------------------------------------------

class _ReverseDialog extends StatefulWidget {
  const _ReverseDialog({required this.lastEvent});

  final CheckEventRow lastEvent;

  @override
  State<_ReverseDialog> createState() => _ReverseDialogState();
}

class _ReverseDialogState extends State<_ReverseDialog> {
  final _reason = TextEditingController();
  final _reasonFocus = FocusNode();
  final _reasonKey = GlobalKey<FormFieldState<String>>();

  @override
  void dispose() {
    _reason.dispose();
    _reasonFocus.dispose();
    super.dispose();
  }

  String? _validateReason() {
    final reason = _reason.text.trim();
    return (reason.isEmpty || reason.length > 100)
        ? 'forms.checks.reasonRequired'
        : null;
  }

  Future<void> _confirm() async {
    final ok = await ensureNoPendency(context, [
      PendencyField(
          name: 'reason',
          validate: _validateReason,
          focusNode: _reasonFocus,
          fieldKey: _reasonKey),
    ]);
    if (!ok || !mounted) return;
    Navigator.of(context).pop(_reason.text.trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: SetesText('forms.checks.reverseTitle'.tr()),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SetesText('forms.checks.reverseConfirm'.tr(args: [
                '${widget.lastEvent.event}',
                checkEventKindLabel(widget.lastEvent.kind),
              ])),
              const SizedBox(height: 16),
              SetesTextField(
                label: 'forms.checks.reason'.tr(),
                controller: _reason,
                focusNode: _reasonFocus,
                fieldKey: _reasonKey,
                autofocus: true,
                validator: (_) => _validateReason()?.tr(),
                onSubmitted: (_) => _confirm(),
              ),
            ],
          ),
        ),
        actions: [
          SetesButton(
            label: 'register.cancel'.tr(),
            kind: SetesButtonKind.text,
            onPressed: () => Navigator.of(context).pop(),
          ),
          SetesButton(
            label: 'forms.checks.confirmReverse'.tr(),
            kind: SetesButtonKind.text,
            onPressed: _confirm,
          ),
        ],
      );
}

/// Abre o dialog ESTORNAR — devolve o motivo (a tela sempre estorna o
/// evento mais recente, [lastEvent]).
Future<String?> showCheckReverseDialog(
        BuildContext context, CheckEventRow lastEvent) =>
    showDialog<String>(
      context: context,
      builder: (_) => _ReverseDialog(lastEvent: lastEvent),
    );

// -----------------------------------------------------------------------
// Feedback do fields[] quando o dialog JÁ fechou (o bloc executa o POST) —
// ancora pelo name do payload das 7 ações; sem correspondência,
// [showUnanchoredServerField] mostra campo + mensagem (nunca genérico).
// -----------------------------------------------------------------------

String? _none() => null;

Future<void> showChecksServerFieldFeedback(
        BuildContext context, Failure failure) =>
    showServerFieldFeedback(context, failure, const [
      PendencyField(name: 'dtRecord', validate: _none),
      PendencyField(name: 'bankAccountId', validate: _none),
      PendencyField(name: 'factoringEntityId', validate: _none),
      PendencyField(name: 'feeValue', validate: _none),
      PendencyField(name: 'orderId', validate: _none),
      PendencyField(name: 'parcel', validate: _none),
      PendencyField(name: 'note', validate: _none),
      PendencyField(name: 'event', validate: _none),
      PendencyField(name: 'reason', validate: _none),
    ]);
