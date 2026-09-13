import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/entity/widgets/entity_date.dart';
import '../../../../shared/feedback/feedback.dart';
import '../../../../shared/feedback/form_pendency.dart';
import '../../../../shared/field_config/entity/field_config_entity.dart';
import '../../../../shared/field_config/field_config_loader.dart';
import '../../../../shared/field_config/field_config_of.dart';
import '../../../../shared/register/register_search_page.dart';
import '../../data/datasource/settlement_rule_lookup_datasource.dart';
import '../../domain/entity/settlement_rule_entity.dart';
import '../bloc/settlement_rule_bloc.dart';

/// Tela de Regras de Recebimento — interface 'settlement-rules', grupo
/// Financeiro (prompt_contrato_financeiro_baixa_automatica.md, D1–D22).
///
/// Lista = forma de pagamento, destino da baixa (Caixa × conta corrente),
/// taxa %, prazo em dias e validade. Form = forma (lookup dedicado —
/// PK, somente-leitura na edição), destino Caixa × Conta corrente (Caixa
/// ⇒ bankAccountId 0 — D1), taxa 0–100, prazo ≥ 0, validade informativa
/// (vencido: avisa e o título nasce em aberto — D11) e observação.
///
/// Feedback 100% via PONTE (Framework de Mensagens): validação
/// uma-pendência-por-vez (R3), fields[] do servidor ancorado no campo,
/// exclusão via decisão tipada (R4). A page só toca o datasource de
/// LOOKUP dedicado; dados via bloc.
class SettlementRulePage extends StatefulWidget {
  const SettlementRulePage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das duas telas.
  final String title;

  @override
  State<SettlementRulePage> createState() => _SettlementRulePageState();
}

class _SettlementRulePageState extends State<SettlementRulePage>
    with FieldConfigLoader {
  late final SettlementRuleBloc _bloc;
  late final SettlementRuleLookupDatasource _lookup;

  /// Acesso ao estado do form: ancora o fields[] do servidor no campo. O
  /// form só está montado no modo formulário — na lista o currentState é
  /// null.
  final _formViewKey = GlobalKey<_SettlementRuleFormViewState>();

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<SettlementRuleBloc>()
      ..add(const SettlementRuleListRequested(''));
    _lookup = Modular.get<SettlementRuleLookupDatasource>();
    loadFieldConfig('settlement-rules'); // engine de campos configuráveis
  }

  /// Destino da baixa na linha: "Caixa" quando bankAccountId == 0.
  static String _destination(SettlementRuleListItem c) => c.isCashier
      ? 'forms.settlementRule.destinationCashier'.tr()
      : (c.bankAccountLabel ?? '');

  Widget _buildSearch(SettlementRuleListState state) =>
      RegisterSearchPage<SettlementRuleListItem>(
        title: 'register.listTitle'.tr(args: [widget.title]),
        // Engrenagem padrão da lista (Framework de Configurações)
        configModuleKey: 'settlement-rules',
        items: state.items,
        loading: state.loading,
        avatarBuilder: (c) => c.isCashier ? 'C' : 'B',
        rowBuilder: (c) => [
          c.paymentTypeDescription ?? '${c.paymentTypeId}',
          'forms.settlementRule.destinationRow'
              .tr(args: [_destination(c)]),
          'forms.settlementRule.termsRow'.tr(args: [
            _formatRate(c.feeRate),
            '${c.paymentTerm}',
          ]),
          if (c.expirationDate != null && c.expirationDate!.isNotEmpty)
            'forms.settlementRule.expirationRow'
                .tr(args: [isoDateToDisplay(c.expirationDate)]),
        ],
        page: state.page,
        pageSize: state.pageSize,
        total: state.total,
        onPageChanged: (page) => _bloc
            .add(SettlementRuleListRequested(state.filter, page: page)),
        onPageSizeChanged: (size) => _bloc
            .add(SettlementRuleListRequested(state.filter, pageSize: size)),
        onFilterChanged: (filter) =>
            _bloc.add(SettlementRuleListRequested(filter)),
        onNew: () => _bloc.add(const SettlementRuleNewPressed()),
        onView: (c) => _bloc.add(SettlementRuleEditPressed(c.id)),
      );

  Widget _buildForm(SettlementRuleFormState state) =>
      _SettlementRuleFormView(
        key: _formViewKey,
        title: widget.title,
        state: state,
        lookup: _lookup,
        fieldConfig: fieldConfig,
        onSave: (event) => _bloc.add(event),
        onBack: () => _bloc.add(const SettlementRuleBackToListPressed()),
        onDelete: state.editing == null
            ? null
            : () => _bloc
                .add(SettlementRuleDeleteRequested(state.editing!.id)),
      );

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<SettlementRuleBloc, SettlementRuleState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is SettlementRuleActionSuccess ||
            current is SettlementRuleActionFailure,
        // PONTE de feedback: sucesso = SnackBar via ponte (R1); falha =
        // dialog, com fields[] do servidor ancorado no campo quando o form
        // está montado (400 PAYMENT_TYPE_NOT_LINKED/BANK_NOT_FOUND, 409
        // FINANCIAL_CONTRACT_EXISTS em paymentTypeId).
        listener: (context, state) {
          if (state is SettlementRuleActionSuccess) {
            showSuccessFeedback(context, state.messageKey);
            return;
          }
          final failure = (state as SettlementRuleActionFailure).failure;
          final form = _formViewKey.currentState;
          if (failure.fields.isNotEmpty && form != null) {
            form.showServerFieldError(failure);
          } else {
            showFailureFeedback(context, failure);
          }
        },
        buildWhen: (_, current) =>
            current is SettlementRuleListState ||
            current is SettlementRuleFormState,
        builder: (context, state) => switch (state) {
          SettlementRuleFormState() => _buildForm(state),
          SettlementRuleListState() => _buildSearch(state),
          _ => _buildSearch(const SettlementRuleListState(loading: true)),
        },
      );
}

/// Taxa em % no formato pt-BR de exibição ("2,50").
String _formatRate(double rate) =>
    rate.toStringAsFixed(2).replaceAll('.', ',');

/// Parse pt-BR ("2,5" / "1.234,56") → double; null quando inválido.
double? _parseDecimal(String text) =>
    double.tryParse(text.replaceAll('.', '').replaceAll(',', '.'));

/// Destino da baixa (D1): 'C' caixa (bankAccountId 0) × 'B' conta corrente.
const _destCashier = 'C';
const _destBank = 'B';

/// Form do regra de recebimento (SetesFormShell): forma (lookup, PK) +
/// destino Caixa × Conta corrente + taxa/prazo + validade + observação.
class _SettlementRuleFormView extends StatefulWidget {
  const _SettlementRuleFormView({
    required this.title,
    required this.state,
    required this.lookup,
    required this.fieldConfig,
    required this.onSave,
    required this.onBack,
    required this.onDelete,
    super.key,
  });

  final String title;
  final SettlementRuleFormState state;
  final SettlementRuleLookupDatasource lookup;

  /// Catálogo resolvido da interface (tb_interface_has_field × cliente).
  final List<FieldConfigEntity> fieldConfig;
  final void Function(SettlementRuleSaveRequested event) onSave;
  final VoidCallback onBack;
  final VoidCallback? onDelete;

  @override
  State<_SettlementRuleFormView> createState() =>
      _SettlementRuleFormViewState();
}

class _SettlementRuleFormViewState
    extends State<_SettlementRuleFormView> {
  late final TextEditingController _paymentTypeText;
  late final TextEditingController _feeRate;
  late final TextEditingController _paymentTerm;
  late final TextEditingController _expirationDate;
  late final TextEditingController _note;

  // R3: foco programático + marca inline SÓ do campo pendente.
  final _focus = {
    for (final name in _fieldNames) name: FocusNode(),
  };
  final _keys = {
    for (final name in _fieldNames) name: GlobalKey<FormFieldState<String>>(),
  };

  /// Nomes do PAYLOAD (camelCase) na ordem da tela — casam com o fields[]
  /// do servidor (DTOs Zod do módulo settlement-rules).
  static const _fieldNames = [
    'feeRate', 'paymentTerm', 'expirationDate', 'note',
  ];

  /// Forma escolhida no lookup — id salvo (PK), descrição exibida.
  int? _paymentTypeId;
  String _paymentTypeDisplay = '';

  /// Destino da baixa: Caixa (conta 0) × Conta corrente (lookup).
  String _destination = _destCashier;
  int? _bankAccountId;
  String _bankAccountDisplay = '';

  SettlementRuleFull? get _editing => widget.state.editing;
  bool get _creating => _editing == null;

  @override
  void initState() {
    super.initState();
    final editing = _editing;
    _paymentTypeId      = editing?.paymentTypeId;
    _paymentTypeDisplay = editing?.paymentTypeDescription ?? '';
    _paymentTypeText = TextEditingController(text: _paymentTypeDisplay);
    if (editing != null && !editing.isCashier) {
      _destination        = _destBank;
      _bankAccountId      = editing.bankAccountId;
      _bankAccountDisplay = editing.bankAccountLabel ?? '';
    }
    _feeRate = TextEditingController(
        text: editing == null ? '' : _formatRate(editing.feeRate));
    _paymentTerm = TextEditingController(
        text: editing == null ? '' : '${editing.paymentTerm}');
    _expirationDate =
        TextEditingController(text: isoDateToDisplay(editing?.expirationDate));
    _note = TextEditingController(text: editing?.note ?? '');
  }

  @override
  void dispose() {
    _paymentTypeText.dispose();
    _feeRate.dispose();
    _paymentTerm.dispose();
    _expirationDate.dispose();
    _note.dispose();
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPaymentType() async {
    final picked = await showSetesLookup<PaymentTypeLookup>(
      context: context,
      title: 'lookup.paymentTypes'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: widget.lookup.paymentTypes,
      itemId: (p) => p.id,
      // Forma já contratada (1 contrato por forma — D2): indicada na lista.
      itemLabel: (p) => p.hasContract
          ? '${p.description} (${'forms.settlementRule.alreadyContracted'.tr()})'
          : p.description,
    );
    if (picked == null || !mounted) return;
    if (picked.hasContract) {
      // Bloqueio no app — a API também recusa (409 FINANCIAL_CONTRACT_EXISTS).
      await showValidationFeedback(
          context, 'forms.settlementRule.alreadyContractedMessage'.tr());
      return;
    }
    setState(() {
      _paymentTypeId      = picked.id;
      _paymentTypeDisplay = picked.description;
    });
  }

  Future<void> _pickBankAccount() async {
    final picked = await showSetesLookup<BankAccountLookup>(
      context: context,
      title: 'lookup.bankAccounts'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: widget.lookup.bankAccounts,
      itemId: (b) => b.id,
      itemLabel: (b) => b.label,
    );
    if (picked != null) {
      setState(() {
        _bankAccountId      = picked.id;
        _bankAccountDisplay = picked.label;
      });
    }
  }

  // ------------------------------------------------------------------
  // Catálogo de campos: caption/required do cliente.
  // ------------------------------------------------------------------

  FieldConfigEntity? _cfg(String field) =>
      fieldConfigOf(widget.fieldConfig, field);

  String _label(String field, String i18nKey) =>
      _cfg(field)?.caption ?? i18nKey.tr();

  bool _requiredCfg(String field) => _cfg(field)?.required ?? false;

  // ------------------------------------------------------------------
  // Validação (R3/R6): DTO Zod como fonte (feeRate 0..100, paymentTerm
  // inteiro 0..3650, expirationDate data ou vazio, note máx 2000).
  // ------------------------------------------------------------------

  /// Taxa (%) OBRIGATÓRIA: parse pt-BR, 0 ≤ taxa ≤ 100.
  String? _validateFeeRate(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'register.requiredField'
          .tr(args: [_label('fee_rate', 'forms.settlementRule.feeRate')]);
    }
    final parsed = _parseDecimal(text);
    if (parsed == null || parsed < 0 || parsed > 100) {
      return 'forms.settlementRule.feeRateInvalid'.tr();
    }
    return null;
  }

  /// Prazo (dias) OBRIGATÓRIO: inteiro 0..3650.
  String? _validatePaymentTerm(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'register.requiredField'.tr(
          args: [_label('payment_term', 'forms.settlementRule.paymentTerm')]);
    }
    final parsed = int.tryParse(text);
    if (parsed == null || parsed < 0 || parsed > 3650) {
      return 'forms.settlementRule.paymentTermInvalid'.tr();
    }
    return null;
  }

  /// Validade OPCIONAL (informativa — D2/D11); cliente pode apertar.
  String? _validateExpirationDate(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return _requiredCfg('expiration_date')
          ? 'register.requiredField'.tr(args: [
              _label('expiration_date', 'forms.settlementRule.expirationDate')
            ])
          : null;
    }
    return displayDateToIso(text) == null ? 'register.invalidDate'.tr() : null;
  }

  /// Observação OPCIONAL, máx 2000 (DTO).
  String? _validateNote(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return _requiredCfg('note')
          ? 'register.requiredField'
              .tr(args: [_label('note', 'forms.settlementRule.note')])
          : null;
    }
    return text.length > 2000 ? 'forms.validation.maxLength'.tr() : null;
  }

  /// Campos NA ORDEM da tela (R3). Os names casam com o payload da API —
  /// é por eles que o fields[] do servidor ancora no campo.
  List<PendencyField> get _pendencyFields => [
        PendencyField(
          name: 'paymentTypeId',
          validate: () => _paymentTypeId == null
              ? 'register.requiredField'.tr(args: [
                  _label('tb_payment_types_id',
                      'forms.settlementRule.paymentType')
                ])
              : null,
        ),
        PendencyField(
          name: 'bankAccountId',
          validate: () =>
              _destination == _destBank && _bankAccountId == null
                  ? 'register.requiredField'.tr(args: [
                      _label('tb_bank_account_id',
                          'forms.settlementRule.bankAccount')
                    ])
                  : null,
        ),
        _text('feeRate', () => _validateFeeRate(_feeRate.text)),
        _text('paymentTerm', () => _validatePaymentTerm(_paymentTerm.text)),
        _text('expirationDate',
            () => _validateExpirationDate(_expirationDate.text)),
        _text('note', () => _validateNote(_note.text)),
      ];

  PendencyField _text(String name, String? Function() validate) =>
      PendencyField(
        name: name,
        focusNode: _focus[name],
        fieldKey: _keys[name],
        validate: validate,
      );

  /// Ancora o fields[] do envelope 400/409 no campo (chamado pelo listener
  /// do bloc via GlobalKey).
  Future<void> showServerFieldError(Failure failure) =>
      showServerFieldFeedback(context, failure, _pendencyFields);

  Future<void> _save() async {
    if (!await ensureNoPendency(context, _pendencyFields)) return;
    final note = _note.text.trim();
    widget.onSave(SettlementRuleSaveRequested(
      editingId: _editing?.id,
      input: SettlementRuleInput(
        paymentTypeId:  _paymentTypeId!,
        // D1: Caixa = conta 0 (o lookup de conta some).
        bankAccountId:  _destination == _destCashier ? 0 : _bankAccountId!,
        feeRate:        _parseDecimal(_feeRate.text.trim()) ?? 0,
        paymentTerm:    int.parse(_paymentTerm.text.trim()),
        expirationDate: displayDateToIso(_expirationDate.text),
        note:           note.isEmpty ? null : note,
      ),
    ));
  }

  /// Exclusão confirmada via decisão TIPADA da ponte (R4): Sim = excluir;
  /// Cancelar (ou fechar) = nada.
  Future<void> _confirmDelete() async {
    final decision = await askDecision(
      context,
      message: 'register.confirmDelete'.tr(),
      yesLabel: 'register.delete'.tr(),
    );
    if (decision == SetesDecision.yes) widget.onDelete?.call();
  }

  /// Texto auxiliar abaixo de um campo — cores do tema (nunca hardcode).
  Widget _helper(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 4),
      child: Text(
        text,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Tabulação: Tab só nos campos editáveis na ordem declarada; lookups e
    // o rádio ficam fora da sequência.
    var order = 0;
    Widget field(Widget child) => FocusTraversalOrder(
        order: NumericFocusOrder((++order).toDouble()), child: child);

    return SetesFormShell(
      title: widget.title,
      saving: widget.state.saving,
      onBack: widget.onBack,
      onSave: _save,
      onDelete: widget.onDelete != null ? _confirmDelete : null,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Forma de pagamento = PK: lookup na criação, somente-leitura
            // na edição.
            if (_creating)
              SetesLookupField(
                label: _label(
                    'tb_payment_types_id', 'forms.settlementRule.paymentType'),
                display: _paymentTypeDisplay,
                onSearch: _pickPaymentType,
                onClear: () => setState(() {
                  _paymentTypeId = null;
                  _paymentTypeDisplay = '';
                }),
              )
            else
              SetesTextField(
                label: _label(
                    'tb_payment_types_id', 'forms.settlementRule.paymentType'),
                controller: _paymentTypeText,
                readOnly: true,
              ),
            const SizedBox(height: 16),
            SetesRadioGroup<String>(
              label: _label(
                  'tb_bank_account_id', 'forms.settlementRule.destination'),
              helperText: 'forms.settlementRule.destinationHelper'.tr(),
              value: _destination,
              options: [
                SetesRadioOption(
                    value: _destCashier,
                    label: 'forms.settlementRule.destinationCashier'.tr()),
                SetesRadioOption(
                    value: _destBank,
                    label: 'forms.settlementRule.destinationBank'.tr()),
              ],
              onChanged: (value) => setState(() {
                _destination = value ?? _destCashier;
                if (_destination == _destCashier) {
                  _bankAccountId = null;
                  _bankAccountDisplay = '';
                }
              }),
            ),
            if (_destination == _destBank) ...[
              const SizedBox(height: 16),
              SetesLookupField(
                label: _label(
                    'tb_bank_account_id', 'forms.settlementRule.bankAccount'),
                display: _bankAccountDisplay,
                onSearch: _pickBankAccount,
                onClear: () => setState(() {
                  _bankAccountId = null;
                  _bankAccountDisplay = '';
                }),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: field(SetesTextField(
                    label: _label('fee_rate', 'forms.settlementRule.feeRate'),
                    hint: 'forms.settlementRule.feeRateHint'.tr(),
                    controller: _feeRate,
                    focusNode: _focus['feeRate'],
                    fieldKey: _keys['feeRate'],
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    validator: _validateFeeRate,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      LengthLimitingTextInputFormatter(7),
                    ],
                  )),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: field(SetesTextField(
                    label: _label(
                        'payment_term', 'forms.settlementRule.paymentTerm'),
                    hint: 'forms.settlementRule.paymentTermHint'.tr(),
                    controller: _paymentTerm,
                    focusNode: _focus['paymentTerm'],
                    fieldKey: _keys['paymentTerm'],
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    validator: _validatePaymentTerm,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                  )),
                ),
              ],
            ),
            const SizedBox(height: 16),
            field(SetesTextField(
              label: _label(
                  'expiration_date', 'forms.settlementRule.expirationDate'),
              hint: 'register.dateHint'.tr(),
              controller: _expirationDate,
              focusNode: _focus['expirationDate'],
              fieldKey: _keys['expirationDate'],
              textInputAction: TextInputAction.next,
              validator: _validateExpirationDate,
            )),
            // D11: vencido → avisa e o título nasce em aberto (nunca bloqueia).
            _helper(
                context, 'forms.settlementRule.expirationDateHelper'.tr()),
            const SizedBox(height: 16),
            field(SetesTextField(
              label: _label('note', 'forms.settlementRule.note'),
              controller: _note,
              focusNode: _focus['note'],
              fieldKey: _keys['note'],
              maxLines: 4,
              textInputAction: TextInputAction.done,
              validator: _validateNote,
              inputFormatters: [LengthLimitingTextInputFormatter(2000)],
            )),
          ],
        ),
      ),
    );
  }
}
