import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/entity/widgets/entity_date.dart';
import '../../../../shared/feedback/feedback.dart';
import '../../../../shared/format/money.dart';
import '../../../../shared/register/register_config_button.dart';
import '../../data/datasource/cashier_datasource.dart';
import '../../domain/entity/cashier_entity.dart';
import '../bloc/cashier_bloc.dart';

/// Tela de Abertura/Fechamento de Caixa — interface 'cashier', grupo
/// Financeiro. 3º TIPO de tela do produto (skill tela-de-processo.md):
/// SESSÃO/STATUS — não é lista+form nem árvore. Sem sessão aberta hoje →
/// estado vazio com "Abrir Caixa"; com sessão aberta → painel com o saldo
/// DERIVADO no servidor + formas de pagamento, "Retirar/Transferir" e
/// "Fechar Caixa" (dialog de conferência → RELATÓRIO registrado × contado
/// × diferença — nunca só um "ok").
class CashierPage extends StatefulWidget {
  const CashierPage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título da tela.
  final String title;

  @override
  State<CashierPage> createState() => _CashierPageState();
}

class _CashierPageState extends State<CashierPage> {
  late final CashierBloc _bloc;
  late final CashierDatasource _datasource;

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<CashierBloc>()..add(const CashierStarted());
    _datasource = Modular.get<CashierDatasource>();
  }

  Future<void> _openWithdrawDialog() async {
    final input = await showDialog<CashierWithdrawInput>(
      context: context,
      builder: (_) => _WithdrawDialog(datasource: _datasource),
    );
    if (input != null) _bloc.add(CashierWithdrawRequested(input));
  }

  Future<void> _openCloseDialog(CashierDetail detail) async {
    final input = await showDialog<CashierCloseInput>(
      context: context,
      builder: (_) => _CloseDialog(detail: detail, datasource: _datasource),
    );
    if (input != null) _bloc.add(CashierCloseRequested(input));
  }

  /// RELATÓRIO do fechamento — registrado × contado × diferença por forma
  /// (R5 da tela de processo: nunca só "ok").
  Future<void> _showCloseReport(CashierCloseResult result) => showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: SetesText('forms.cashier.closeReportTitle'.tr()),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in result.items) ...[
                    SetesText(item.paymentTypeDescription ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    SetesText([
                      'forms.cashier.registeredRow'
                          .tr(args: [setesMoney(item.registeredValue)]),
                      'forms.cashier.countedRow'
                          .tr(args: [setesMoney(item.countedValue)]),
                      'forms.cashier.differenceRow'
                          .tr(args: [setesMoney(item.difference)]),
                    ].join(' · ')),
                    const SizedBox(height: 8),
                  ],
                  if (result.items.isEmpty)
                    SetesText('register.emptyList'.tr()),
                  if (result.transfer != null) ...[
                    const Divider(height: 24),
                    SetesText('forms.cashier.transferDone'.tr()),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            SetesButton(
              label: 'register.ok'.tr(),
              kind: SetesButtonKind.text,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        ),
      );

  Widget _buildEmpty(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.point_of_sale_outlined,
                size: 64, color: theme.colorScheme.secondary),
            const SizedBox(height: 16),
            SetesText('forms.cashier.noCashierOpen'.tr()),
            const SizedBox(height: 24),
            SetesButton(
              label: 'forms.cashier.openCashier'.tr(),
              icon: Icons.add,
              onPressed: () => _bloc.add(const CashierOpenRequested()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentTypeTile(CashierPaymentTypeBalance item) => SetesListTile(
        title: SetesText(item.paymentTypeDescription ?? ''),
        trailing: SetesText(setesMoney(item.value)),
      );

  Widget _buildPanel(BuildContext context, CashierPanelState state) {
    final theme = Theme.of(context);
    final cashier = state.cashier!;
    final detail = state.detail;
    if (detail == null) return const SetesCircularProgressIndicator();
    final busy = state.saving;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SetesCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SetesText(
                'forms.cashier.openedAtRow'.tr(args: [
                  isoDateToDisplay(cashier.dtRecord),
                  cashier.hrBegin ?? '',
                ]),
              ),
              const SizedBox(height: 8),
              SetesText(
                'forms.cashier.balanceRow'.tr(args: [setesMoney(detail.balance)]),
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SetesText.title('forms.cashier.paymentTypes'.tr()),
        const SizedBox(height: 8),
        if (detail.registeredByPaymentType.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SetesText('register.emptyList'.tr()),
          )
        else
          for (final item in detail.registeredByPaymentType) ...[
            _buildPaymentTypeTile(item),
            const Divider(height: 1),
          ],
        const SizedBox(height: 24),
        SetesButton(
          label: 'forms.cashier.withdraw'.tr(),
          icon: Icons.outbox_outlined,
          onPressed: busy ? null : _openWithdrawDialog,
        ),
        const SizedBox(height: 12),
        SetesButton(
          label: 'forms.cashier.closeCashier'.tr(),
          icon: Icons.lock_outline,
          onPressed: busy ? null : () => _openCloseDialog(detail),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<CashierBloc, CashierState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is CashierActionSuccess ||
            current is CashierActionFailure ||
            current is CashierClosed,
        // PONTE de feedback (Framework de Mensagens): a tela nunca chama
        // ScaffoldMessenger/AlertDialog para desfecho — sucesso = SnackBar
        // via ponte (R1); falha = dialog (os 409 de negócio — caixa já
        // aberto/fechado/não aberto — viram validação com a mensagem da
        // API); fechamento concluído abre o dialog do RELATÓRIO.
        listener: (context, state) async {
          if (state is CashierClosed) {
            await _showCloseReport(state.result);
            return;
          }
          if (state is CashierActionSuccess) {
            showSuccessFeedback(context, state.messageKey,
                args: state.args.isEmpty ? null : state.args);
            return;
          }
          final failure = (state as CashierActionFailure).failure;
          if (failure.fields.isNotEmpty) {
            showValidationFeedback(context, failure.fields.first.message.tr());
          } else {
            showFailureFeedback(context, failure);
          }
        },
        buildWhen: (_, current) => current is CashierPanelState,
        builder: (context, state) {
          final panel = state is CashierPanelState
              ? state
              : const CashierPanelState(loading: true);
          return Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: Text(widget.title),
              actions: const [
                RegisterConfigButton(moduleKey: 'cashier'),
              ],
            ),
            body: panel.loading
                ? const SetesCircularProgressIndicator()
                : panel.cashier == null
                    ? _buildEmpty(context)
                    : _buildPanel(context, panel),
          );
        },
      );
}

// -------------------------------------------------------------------
// Checagem de UM campo de dialog de ação (R3 — uma pendência por vez).
// -------------------------------------------------------------------

class _DialogCheck {
  const _DialogCheck({required this.validate, this.focusNode, this.fieldKey});

  final String? Function() validate;
  final FocusNode? focusNode;
  final GlobalKey<FormFieldState<String>>? fieldKey;
}

Future<bool> _firstPendingCheck(
    BuildContext context, List<_DialogCheck> checks) async {
  for (final check in checks) {
    final message = check.validate();
    if (message != null) {
      await showValidationFeedback(context, message.tr());
      if (context.mounted) {
        check.fieldKey?.currentState?.validate();
        check.focusNode?.requestFocus();
      }
      return false;
    }
  }
  return true;
}

double? _parseDecimal(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  return double.tryParse(t.replaceAll(',', '.'));
}

String _decimalText(double value) =>
    value.toStringAsFixed(2).replaceAll('.', ',');

/// Lookup de conta bancária de destino (opcional) — sem opção Caixa fixa
/// (o Caixa É a sessão sendo operada, não um destino).
Future<CashierBankAccountLookup?> _pickBankAccount(
        BuildContext context, CashierDatasource datasource) =>
    showSetesLookup<CashierBankAccountLookup>(
      context: context,
      title: 'lookup.bankAccounts'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: datasource.bankAccounts,
      itemId: (a) => a.id,
      itemLabel: (a) {
        final numbers = 'forms.cashier.accountRow'
            .tr(args: [a.agencyText, a.numberText]);
        return a.bankLabel.isEmpty ? numbers : '${a.bankLabel} · $numbers';
      },
    );

/// Dialog "Retirar/Transferir" (POST /:id/withdraw): valor (>0), histórico
/// (obrigatório, até 100) + conta de destino OPCIONAL — informada vira
/// transferência (crédito espelhado), ausente é retirada simples.
class _WithdrawDialog extends StatefulWidget {
  const _WithdrawDialog({required this.datasource});

  final CashierDatasource datasource;

  @override
  State<_WithdrawDialog> createState() => _WithdrawDialogState();
}

class _WithdrawDialogState extends State<_WithdrawDialog> {
  final _value = TextEditingController();
  final _history = TextEditingController();
  final _valueFocus = FocusNode();
  final _historyFocus = FocusNode();
  final _valueKey = GlobalKey<FormFieldState<String>>();
  final _historyKey = GlobalKey<FormFieldState<String>>();

  CashierBankAccountLookup? _account;

  @override
  void dispose() {
    _value.dispose();
    _history.dispose();
    _valueFocus.dispose();
    _historyFocus.dispose();
    super.dispose();
  }

  String? _validateValue() {
    final value = _parseDecimal(_value.text);
    return (value == null || value <= 0)
        ? 'forms.cashier.withdrawValueInvalid'
        : null;
  }

  String? _validateHistory() {
    final text = _history.text.trim();
    return (text.isEmpty || text.length > 100)
        ? 'forms.cashier.withdrawHistoryRequired'
        : null;
  }

  Future<void> _pickAccount() async {
    final picked = await _pickBankAccount(context, widget.datasource);
    if (picked != null) setState(() => _account = picked);
  }

  Future<void> _confirm() async {
    final ok = await _firstPendingCheck(context, [
      _DialogCheck(
        validate: _validateValue,
        focusNode: _valueFocus,
        fieldKey: _valueKey,
      ),
      _DialogCheck(
        validate: _validateHistory,
        focusNode: _historyFocus,
        fieldKey: _historyKey,
      ),
    ]);
    if (!ok || !mounted) return;
    Navigator.of(context).pop(CashierWithdrawInput(
      value: _parseDecimal(_value.text)!,
      history: _history.text.trim(),
      destinationBankAccountId: _account?.id,
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: SetesText('forms.cashier.withdraw'.tr()),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SetesTextField(
                label: 'forms.cashier.withdrawValue'.tr(),
                controller: _value,
                focusNode: _valueFocus,
                fieldKey: _valueKey,
                autofocus: true,
                keyboardType: TextInputType.number,
                validator: (_) => _validateValue()?.tr(),
              ),
              const SizedBox(height: 16),
              SetesTextField(
                label: 'forms.cashier.withdrawHistory'.tr(),
                controller: _history,
                focusNode: _historyFocus,
                fieldKey: _historyKey,
                validator: (_) => _validateHistory()?.tr(),
              ),
              const SizedBox(height: 16),
              SetesLookupField(
                label: 'forms.cashier.destinationAccount'.tr(),
                display: _account == null
                    ? ''
                    : '${_account!.bankLabel} · ${_account!.numberText}',
                onSearch: _pickAccount,
                onClear: () => setState(() => _account = null),
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
            label: 'register.save'.tr(),
            kind: SetesButtonKind.text,
            onPressed: _confirm,
          ),
        ],
      );
}

/// Controladores de UMA linha de conferência do fechamento — default =
/// valor REGISTRADO (sempre editável); linha deixada em BRANCO não entra
/// no [CashierCloseInput.items].
class _CloseRowFields {
  _CloseRowFields(this.item)
      : counted = TextEditingController(text: _decimalText(item.value));

  final CashierPaymentTypeBalance item;
  final TextEditingController counted;
  final focusNode = FocusNode();
  final fieldKey = GlobalKey<FormFieldState<String>>();

  /// Linha em branco é PERMITIDA (usuário optou por não conferir) — só
  /// valida se preenchida.
  String? validate() {
    if (counted.text.trim().isEmpty) return null;
    final value = _parseDecimal(counted.text);
    return (value == null || value < 0)
        ? 'forms.cashier.countedValueInvalid'
        : null;
  }

  void dispose() {
    counted.dispose();
    focusNode.dispose();
  }
}

/// Dialog de fechamento (POST /:id/close): uma linha por forma de
/// pagamento REGISTRADA (default = registrado, editável, opcionalmente em
/// branco) + conta de destino OPCIONAL para transferir o saldo total.
class _CloseDialog extends StatefulWidget {
  const _CloseDialog({required this.detail, required this.datasource});

  final CashierDetail detail;
  final CashierDatasource datasource;

  @override
  State<_CloseDialog> createState() => _CloseDialogState();
}

class _CloseDialogState extends State<_CloseDialog> {
  late final List<_CloseRowFields> _rows;
  CashierBankAccountLookup? _transferAccount;

  @override
  void initState() {
    super.initState();
    _rows = [
      for (final item in widget.detail.registeredByPaymentType)
        _CloseRowFields(item),
    ];
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _pickTransferAccount() async {
    final picked = await _pickBankAccount(context, widget.datasource);
    if (picked != null) setState(() => _transferAccount = picked);
  }

  Future<void> _confirm() async {
    final ok = await _firstPendingCheck(context, [
      for (final row in _rows)
        _DialogCheck(
          validate: row.validate,
          focusNode: row.focusNode,
          fieldKey: row.fieldKey,
        ),
    ]);
    if (!ok || !mounted) return;
    Navigator.of(context).pop(CashierCloseInput(
      items: [
        for (final row in _rows)
          if (row.counted.text.trim().isNotEmpty)
            CashierCloseItemInput(
              paymentTypeId: row.item.paymentTypeId,
              countedValue: _parseDecimal(row.counted.text)!,
            ),
      ],
      transferBankAccountId: _transferAccount?.id,
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: SetesText('forms.cashier.closeCashier'.tr()),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SetesText('forms.cashier.closeConfirm'.tr()),
                const SizedBox(height: 16),
                if (_rows.isEmpty)
                  SetesText('register.emptyList'.tr())
                else
                  for (final row in _rows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SetesTextField(
                        label: row.item.paymentTypeDescription ?? '',
                        controller: row.counted,
                        focusNode: row.focusNode,
                        fieldKey: row.fieldKey,
                        keyboardType: TextInputType.number,
                        validator: (_) => row.validate()?.tr(),
                      ),
                    ),
                const Divider(height: 1),
                const SizedBox(height: 16),
                SetesLookupField(
                  label: 'forms.cashier.transferAccount'.tr(),
                  display: _transferAccount == null
                      ? ''
                      : '${_transferAccount!.bankLabel} · '
                          '${_transferAccount!.numberText}',
                  onSearch: _pickTransferAccount,
                  onClear: () => setState(() => _transferAccount = null),
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
            label: 'forms.cashier.confirmClose'.tr(),
            kind: SetesButtonKind.text,
            onPressed: _confirm,
          ),
        ],
      );
}
