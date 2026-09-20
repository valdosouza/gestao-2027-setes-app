import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/feedback/feedback.dart';

import '../../../../shared/entity/widgets/entity_date.dart';
import '../../../../shared/feedback/form_pendency.dart';
import '../../../../shared/format/money.dart';
import '../../domain/entity/bank_slip_entity.dart';
import 'bank_slip_format.dart';

/// Detalhe do boleto DIRIGIDO PELO ESTADO (skill tela-de-processo):
/// cabeçalho congelado (nosso nº, documento, emissão, vencimento, valor,
/// conta, taxas, instrução), títulos vinculados e linha do tempo de
/// eventos. Ações: ABERTO → Baixar (dialog paidValue/dtPayment) e Cancelar
/// (delete_outline na AppBar, nota opcional); LIQUIDADO → Estornar (motivo
/// obrigatório); CANCELADO → somente leitura. Cada ação dispara o evento
/// do bloc, que chama a API e RECARREGA o detalhe.
class BankSlipDetailView extends StatelessWidget {
  const BankSlipDetailView({
    required this.title,
    required this.slip,
    required this.saving,
    required this.onBack,
    required this.onSettle,
    required this.onCancel,
    required this.onReverse,
    required this.onRegister,
    required this.onRefresh,
    required this.onPdf,
    super.key,
  });

  final String title;
  final BankSlipFull slip;
  final bool saving;
  final VoidCallback onBack;
  final void Function(double paidValue, String dtPayment) onSettle;
  final void Function(String? note) onCancel;
  final void Function(String reason) onReverse;

  /// Onda 2 — o boleto no BANCO: apresentar, consultar e PDF oficial.
  final VoidCallback onRegister;
  final VoidCallback onRefresh;
  final VoidCallback onPdf;

  Future<void> _openSettleDialog(BuildContext context) async {
    final result = await showDialog<(double, String)>(
      context: context,
      builder: (_) => _SettleDialog(slip: slip),
    );
    if (result != null) onSettle(result.$1, result.$2);
  }

  Future<void> _openCancelDialog(BuildContext context) async {
    final result = await showDialog<_CancelResult>(
      context: context,
      builder: (_) => const _CancelDialog(),
    );
    if (result != null) onCancel(result.note);
  }

  Future<void> _openReverseDialog(BuildContext context) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _ReverseDialog(),
    );
    if (reason != null) onReverse(reason);
  }

  Widget _stateBadge(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (slip.state) {
      BankSlipStatus.settled => (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer
        ),
      BankSlipStatus.cancelled => (
          scheme.errorContainer,
          scheme.onErrorContainer
        ),
      _ => (scheme.primaryContainer, scheme.onPrimaryContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SetesText(bankSlipStateLabel(slip.state),
          style: TextStyle(color: foreground, fontSize: 12)),
    );
  }

  Widget _row(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: SetesText(text),
      );

  /// Percentual congelado ('2,00%') — só exibe quando informado.
  String _pct(double value) => '${bankSlipDecimalText(value)}%';

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return SetesCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SetesText(
                  slip.customerName ?? '',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              _stateBadge(context),
            ],
          ),
          const SizedBox(height: 8),
          _row('forms.bankSlip.ourNumberRow'.tr(args: [slip.ourNumber])),
          _row('forms.bankSlip.documentRow'.tr(args: [slip.documentNumber])),
          _row('forms.bankSlip.emissionRow'
              .tr(args: [isoDateToDisplay(slip.dtEmission)])),
          _row('forms.bankSlip.expirationRow'
              .tr(args: [isoDateToDisplay(slip.dtExpiration)])),
          if (slip.bankAccountLabel != null &&
              slip.bankAccountLabel!.isNotEmpty)
            _row('forms.bankSlip.accountRow'.tr(args: [slip.bankAccountLabel!])),
          const SizedBox(height: 8),
          SetesText(
            'forms.bankSlip.valueRow'.tr(args: [setesMoney(slip.value)]),
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  /// Taxas/instruções CONGELADAS na emissão (snapshot da carteira — §2 do
  /// prompt). Só as informadas aparecem.
  Widget _buildFrozenRates(BuildContext context) {
    final rows = <String>[
      if (slip.accept != null && slip.accept!.isNotEmpty)
        'forms.bankSlip.acceptRow'.tr(args: [slip.accept!]),
      if (slip.aliqInterest != null)
        'forms.bankSlip.aliqInterestRow'.tr(args: [_pct(slip.aliqInterest!)]),
      if (slip.aliqLate != null)
        'forms.bankSlip.aliqLateRow'.tr(args: [_pct(slip.aliqLate!)]),
      if (slip.valueLateMin != null)
        'forms.bankSlip.valueLateMinRow'
            .tr(args: [setesMoney(slip.valueLateMin!)]),
      if (slip.aliqFine != null)
        'forms.bankSlip.aliqFineRow'.tr(args: [_pct(slip.aliqFine!)]),
      if (slip.valueFine != null)
        'forms.bankSlip.valueFineRow'.tr(args: [setesMoney(slip.valueFine!)]),
      if (slip.aliqDiscount != null)
        'forms.bankSlip.aliqDiscountRow'.tr(args: [_pct(slip.aliqDiscount!)]),
      if (slip.discountValue != null)
        'forms.bankSlip.discountValueRow'
            .tr(args: [setesMoney(slip.discountValue!)]),
      if (slip.dtDiscountUntil != null && slip.dtDiscountUntil!.isNotEmpty)
        'forms.bankSlip.dtDiscountUntilRow'
            .tr(args: [isoDateToDisplay(slip.dtDiscountUntil)]),
      if (slip.valueRate != null)
        'forms.bankSlip.valueRateRow'.tr(args: [setesMoney(slip.valueRate!)]),
      if (slip.protestDays != null)
        'forms.bankSlip.protestDaysRow'.tr(args: ['${slip.protestDays}']),
      if (slip.instruction != null && slip.instruction!.isNotEmpty)
        'forms.bankSlip.instructionRow'.tr(args: [slip.instruction!]),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        SetesText.title('forms.bankSlip.frozenRates'.tr()),
        const SizedBox(height: 8),
        SetesCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final row in rows) _row(row)],
          ),
        ),
      ],
    );
  }

  Widget _buildTitleTile(BankSlipTitleRow row) {
    final cells = [
      if (row.number != null && row.number!.isNotEmpty)
        'forms.bankSlip.titleNumberRow'.tr(args: [row.number!]),
      'forms.bankSlip.expirationRow'
          .tr(args: [isoDateToDisplay(row.dtExpiration)]),
      'forms.bankSlip.valueRow'.tr(args: [setesMoney(row.value)]),
    ].where((cell) => cell.isNotEmpty);
    return SetesListTile(
      leading: CircleAvatar(child: SetesText('${row.parcel}')),
      title: SetesText(row.entityName ?? ''),
      subtitle: SetesText(cells.join(' · ')),
    );
  }

  Future<void> _copy(BuildContext context, String text, String doneKey) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) await showSuccessFeedback(context, doneKey);
  }

  /// Onda 2 — seção "No banco": apresentação vigente (situação, código,
  /// linha digitável/Pix com copiar), PENDÊNCIAS (recebido no banco sem
  /// liquidar aqui — D-I10), ações e a voz do banco em linha do tempo.
  Widget _buildBankSection(BuildContext context) {
    final theme = Theme.of(context);
    final reg = slip.lastRegistration;
    final refused = slip.refusedEffects;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        SetesText.title('forms.bankSlip.bankSection'.tr()),
        const SizedBox(height: 8),
        SetesCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (reg == null)
                _row('forms.bankSlip.bankNotRegistered'.tr())
              else ...[
                _row('forms.bankSlip.bankAttemptRow'.tr(args: [
                  '${reg.attempt}',
                  reg.environment == 'P'
                      ? 'forms.bankSlip.envProduction'.tr()
                      : 'forms.bankSlip.envSandbox'.tr(),
                ])),
                _row('forms.bankSlip.bankStatusRow'.tr(args: [
                  bankSlipRegistrationKindLabel(reg.lastKind),
                  reg.lastBankStatus ?? '',
                ])),
                if (reg.requestCode != null)
                  _row('forms.bankSlip.bankRequestCodeRow'.tr(args: [reg.requestCode!])),
                if (reg.bankOurNumber != null)
                  _row('forms.bankSlip.bankOurNumberRow'.tr(args: [reg.bankOurNumber!])),
                if (reg.digitableLine != null)
                  SetesTextField(
                    label: 'forms.bankSlip.digitableLine'.tr(),
                    controller: TextEditingController(text: reg.digitableLine),
                    readOnly: true,
                    suffixIcon: Icons.copy,
                    onSuffixPressed: () =>
                        _copy(context, reg.digitableLine!, 'forms.bankSlip.copied'),
                  ),
                if (reg.pixCopyPaste != null) ...[
                  const SizedBox(height: 8),
                  SetesTextField(
                    label: 'forms.bankSlip.pixCopyPaste'.tr(),
                    controller: TextEditingController(text: reg.pixCopyPaste),
                    readOnly: true,
                    suffixIcon: Icons.copy,
                    onSuffixPressed: () =>
                        _copy(context, reg.pixCopyPaste!, 'forms.bankSlip.copied'),
                  ),
                ],
              ],
              for (final p in refused)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SetesText(
                    'forms.bankSlip.bankPendingRow'.tr(args: [
                      isoDateToDisplay(p.dtBankStatus?.substring(0, 10)),
                      p.paidValue == null ? '' : setesMoney(p.paidValue!),
                      p.message ?? '',
                    ]),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (slip.isOpen && !slip.hasLiveRegistration)
                    SetesButton(
                      label: 'forms.bankSlip.register'.tr(),
                      icon: Icons.cloud_upload_outlined,
                      loading: saving,
                      onPressed: saving ? null : onRegister,
                    ),
                  if (reg != null && reg.requestCode != null)
                    SetesButton(
                      label: 'forms.bankSlip.refresh'.tr(),
                      icon: Icons.sync,
                      kind: SetesButtonKind.secondary,
                      loading: saving,
                      onPressed: saving ? null : onRefresh,
                    ),
                  if (reg != null && reg.requestCode != null)
                    SetesButton(
                      label: 'forms.bankSlip.pdf'.tr(),
                      icon: Icons.picture_as_pdf_outlined,
                      kind: SetesButtonKind.secondary,
                      loading: saving,
                      onPressed: saving ? null : onPdf,
                    ),
                ],
              ),
            ],
          ),
        ),
        if (slip.registrationEvents.isNotEmpty) ...[
          const SizedBox(height: 16),
          SetesText.title('forms.bankSlip.bankEvents'.tr()),
          const SizedBox(height: 8),
          for (final e in slip.registrationEvents) ...[
            _buildRegistrationEventTile(e),
            const Divider(height: 1),
          ],
        ],
      ],
    );
  }

  Widget _buildRegistrationEventTile(BankSlipRegistrationEvent e) {
    final cells = [
      'forms.bankSlip.bankAttemptShort'.tr(args: ['${e.attempt}']),
      if (e.dtBankStatus != null) isoDateToDisplay(e.dtBankStatus!.substring(0, 10)),
      bankSlipRegistrationSourceLabel(e.source),
      if (e.bankStatus != null && e.bankStatus!.isNotEmpty) e.bankStatus!,
      if (e.paidValue != null) 'forms.bankSlip.paidRow'.tr(args: [setesMoney(e.paidValue!)]),
      if (e.slipEvent != null) 'forms.bankSlip.bankEffectRow'.tr(args: ['${e.slipEvent}']),
      if (e.message != null && e.message!.isNotEmpty) e.message!,
    ].where((c) => c.isNotEmpty);
    return SetesListTile(
      leading: CircleAvatar(child: SetesText('${e.event}')),
      title: SetesText(bankSlipRegistrationKindLabel(e.kind)),
      subtitle: SetesText(cells.join(' · ')),
    );
  }

  /// Linha do tempo: kind traduzido + data/origem + detalhes do evento
  /// (código da baixa, valor pago, evento de origem do estorno, nota).
  Widget _buildEventTile(BankSlipEventRow event) {
    final cells = [
      isoDateToDisplay(event.dtRecord),
      bankSlipEventSourceLabel(event.source),
      if (event.settledCode != null)
        'forms.bankSlip.settledCodeRow'.tr(args: ['${event.settledCode}']),
      if (event.paidValue != null)
        'forms.bankSlip.paidRow'.tr(args: [setesMoney(event.paidValue!)]),
      if (event.originEvent != null)
        'forms.bankSlip.originEventRow'.tr(args: ['${event.originEvent}']),
      if (event.bankMessage != null && event.bankMessage!.isNotEmpty)
        event.bankMessage!,
      if (event.note != null && event.note!.isNotEmpty)
        'forms.bankSlip.noteRow'.tr(args: [event.note!]),
    ].where((cell) => cell.isNotEmpty);
    return SetesListTile(
      leading: CircleAvatar(child: SetesText('${event.event}')),
      title: SetesText(bankSlipEventKindLabel(event.kind)),
      subtitle: SetesText(cells.join(' · ')),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: saving ? null : onBack,
          ),
          title: Text(title),
          actions: [
            if (slip.isOpen)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'forms.bankSlip.cancel'.tr(),
                onPressed: saving ? null : () => _openCancelDialog(context),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeader(context),
            _buildFrozenRates(context),
            const SizedBox(height: 16),
            SetesText.title('forms.bankSlip.titles'.tr()),
            const SizedBox(height: 8),
            if (slip.titleRows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SetesText('register.emptyList'.tr()),
              )
            else
              for (final row in slip.titleRows) ...[
                _buildTitleTile(row),
                const Divider(height: 1),
              ],
            const SizedBox(height: 16),
            SetesText.title('forms.bankSlip.events'.tr()),
            const SizedBox(height: 8),
            for (final event in slip.events) ...[
              _buildEventTile(event),
              const Divider(height: 1),
            ],
            _buildBankSection(context),
            const SizedBox(height: 24),
            // Ações por ESTADO: aberto = Baixar; liquidado = Estornar;
            // cancelado = nada (somente leitura).
            if (slip.isOpen)
              Align(
                alignment: Alignment.centerRight,
                child: SetesButton(
                  label: 'forms.bankSlip.settle'.tr(),
                  icon: Icons.check,
                  loading: saving,
                  onPressed: saving ? null : () => _openSettleDialog(context),
                ),
              ),
            if (slip.isSettled)
              Align(
                alignment: Alignment.centerRight,
                child: SetesButton(
                  label: 'forms.bankSlip.reverse'.tr(),
                  icon: Icons.undo,
                  kind: SetesButtonKind.secondary,
                  loading: saving,
                  onPressed:
                      saving ? null : () => _openReverseDialog(context),
                ),
              ),
          ],
        ),
      );
}

/// Dialog BAIXAR (liquidação manual — D5): valor recebido (default = valor
/// de face) e data do pagamento (default hoje), ambos editáveis. Devolve
/// (paidValue, dtPaymentIso) pelo Navigator.pop.
class _SettleDialog extends StatefulWidget {
  const _SettleDialog({required this.slip});

  final BankSlipFull slip;

  @override
  State<_SettleDialog> createState() => _SettleDialogState();
}

class _SettleDialogState extends State<_SettleDialog> {
  late final TextEditingController _paidValue;
  late final TextEditingController _dtPayment;
  final _paidFocus = FocusNode();
  final _dtFocus = FocusNode();
  final _paidKey = GlobalKey<FormFieldState<String>>();
  final _dtKey = GlobalKey<FormFieldState<String>>();

  @override
  void initState() {
    super.initState();
    _paidValue =
        TextEditingController(text: bankSlipDecimalText(widget.slip.value));
    _dtPayment =
        TextEditingController(text: isoDateToDisplay(bankSlipTodayIso()));
  }

  @override
  void dispose() {
    _paidValue.dispose();
    _dtPayment.dispose();
    _paidFocus.dispose();
    _dtFocus.dispose();
    super.dispose();
  }

  String? _validatePaid() {
    final value = bankSlipParseDecimal(_paidValue.text);
    return (value == null || value <= 0) ? 'forms.bankSlip.paidInvalid' : null;
  }

  String? _validateDate() =>
      displayDateToIso(_dtPayment.text) == null ? 'register.invalidDate' : null;

  Future<void> _confirm() async {
    final ok = await ensureNoPendency(context, [
      PendencyField(
        name: 'paidValue',
        validate: _validatePaid,
        focusNode: _paidFocus,
        fieldKey: _paidKey,
      ),
      PendencyField(
        name: 'dtPayment',
        validate: _validateDate,
        focusNode: _dtFocus,
        fieldKey: _dtKey,
      ),
    ]);
    if (!ok || !mounted) return;
    Navigator.of(context).pop((
      bankSlipParseDecimal(_paidValue.text)!,
      displayDateToIso(_dtPayment.text)!,
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: SetesText('forms.bankSlip.settleTitle'.tr()),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SetesText('forms.bankSlip.settleHint'
                  .tr(args: [widget.slip.ourNumber])),
              const SizedBox(height: 16),
              SetesTextField(
                label: 'forms.bankSlip.paidValue'.tr(),
                controller: _paidValue,
                focusNode: _paidFocus,
                fieldKey: _paidKey,
                autofocus: true,
                keyboardType: TextInputType.number,
                validator: (_) => _validatePaid()?.tr(),
              ),
              const SizedBox(height: 12),
              SetesTextField(
                label: 'forms.bankSlip.dtPayment'.tr(),
                hint: 'register.dateHint'.tr(),
                controller: _dtPayment,
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
            label: 'forms.bankSlip.confirmSettle'.tr(),
            kind: SetesButtonKind.text,
            onPressed: _confirm,
          ),
        ],
      );
}

/// Resultado do dialog de cancelamento (nota opcional — null permitido).
class _CancelResult {
  const _CancelResult(this.note);
  final String? note;
}

/// Dialog CANCELAR (evento C): confirmação com nota OPCIONAL (máx. 255) —
/// libera os títulos para reemissão ou outra forma (D6/D10).
class _CancelDialog extends StatefulWidget {
  const _CancelDialog();

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
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
      _note.text.trim().length > 255 ? 'forms.bankSlip.noteTooLong' : null;

  Future<void> _confirm() async {
    final ok = await ensureNoPendency(context, [
      PendencyField(
        name: 'note',
        validate: _validateNote,
        focusNode: _noteFocus,
        fieldKey: _noteKey,
      ),
    ]);
    if (!ok || !mounted) return;
    final note = _note.text.trim();
    Navigator.of(context).pop(_CancelResult(note.isEmpty ? null : note));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: SetesText('forms.bankSlip.cancelTitle'.tr()),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SetesText('forms.bankSlip.cancelConfirm'.tr()),
              const SizedBox(height: 16),
              SetesTextField(
                label: 'forms.bankSlip.cancelNote'.tr(),
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
            label: 'forms.bankSlip.confirmCancel'.tr(),
            kind: SetesButtonKind.text,
            onPressed: _confirm,
          ),
        ],
      );
}

/// Dialog ESTORNAR (evento X — D10): motivo OBRIGATÓRIO (máx. 100), gravado
/// nos lançamentos inversos das baixas do settled_code.
class _ReverseDialog extends StatefulWidget {
  const _ReverseDialog();

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
        ? 'forms.bankSlip.reasonRequired'
        : null;
  }

  Future<void> _confirm() async {
    final ok = await ensureNoPendency(context, [
      PendencyField(
        name: 'reason',
        validate: _validateReason,
        focusNode: _reasonFocus,
        fieldKey: _reasonKey,
      ),
    ]);
    if (!ok || !mounted) return;
    Navigator.of(context).pop(_reason.text.trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: SetesText('forms.bankSlip.reverseTitle'.tr()),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SetesText('forms.bankSlip.reverseConfirm'.tr()),
              const SizedBox(height: 16),
              SetesTextField(
                label: 'forms.bankSlip.reverseReason'.tr(),
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
            label: 'forms.bankSlip.reverse'.tr(),
            kind: SetesButtonKind.text,
            onPressed: _confirm,
          ),
        ],
      );
}
