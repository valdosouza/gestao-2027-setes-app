import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/feedback/feedback.dart';
import '../../../../shared/feedback/form_pendency.dart';
import '../../../../shared/field_config/entity/field_config_entity.dart';
import '../../../../shared/field_config/field_config_loader.dart';
import '../../../../shared/field_config/field_config_of.dart';
import '../../../../shared/register/register_search_page.dart';
import '../../data/datasource/bank_charge_agreement_datasource.dart';
import '../../domain/entity/bank_charge_agreement_entity.dart';
import '../bloc/bank_charge_agreement_bloc.dart';

/// Tela de Carteiras de Cobrança — interface 'bank-charge-agreements',
/// grupo Financeiro. É a contratação de cobrança com o banco: define a
/// conta de crédito e as taxas/instruções que o BOLETO (módulo bank_slips)
/// CONGELA na emissão.
///
/// Lista = convênio + conta corrente (JOIN da API) + status ativa/inativa.
/// Form = convênio + conta (lookup DEDICADO deste módulo) + ativa/aceite +
/// encargos (juros/mora/multa/desconto/tarifa) + instrução + protesto
/// (revela "dias para protesto" só quando marcado) + próxima sequência do
/// nosso número.
///
/// Feedback 100% via PONTE (Framework de Mensagens): validação
/// uma-pendência-por-vez (R3), fields[] do servidor ancorado no campo,
/// exclusão via decisão tipada (R4). A page só toca o datasource de LOOKUP
/// dedicado (bankAccounts); dados via bloc.
class BankChargeAgreementPage extends StatefulWidget {
  const BankChargeAgreementPage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das duas telas.
  final String title;

  @override
  State<BankChargeAgreementPage> createState() =>
      _BankChargeAgreementPageState();
}

class _BankChargeAgreementPageState extends State<BankChargeAgreementPage>
    with FieldConfigLoader {
  late final BankChargeAgreementBloc _bloc;
  late final BankChargeAgreementDatasource _datasource;

  /// Acesso ao estado do form: ancora o fields[] do servidor no campo. O
  /// form só está montado no modo formulário — na lista o currentState é
  /// null.
  final _formViewKey = GlobalKey<_BankChargeAgreementFormViewState>();

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<BankChargeAgreementBloc>()
      ..add(const BankChargeAgreementListRequested(''));
    _datasource = Modular.get<BankChargeAgreementDatasource>();
    loadFieldConfig('bank-charge-agreements'); // engine de campos configuráveis
  }

  Widget _buildSearch(BankChargeAgreementListState state) =>
      RegisterSearchPage<BankChargeAgreementListItem>(
        title: 'register.listTitle'.tr(args: [widget.title]),
        // Engrenagem padrão da lista (Framework de Configurações)
        configModuleKey: 'bank-charge-agreements',
        items: state.items,
        loading: state.loading,
        avatarBuilder: (a) => '${a.id}',
        rowBuilder: (a) => [
          a.agreement,
          'forms.bankChargeAgreement.bankAccountRow'
              .tr(args: [a.bankAccountDisplay]),
          if (a.active == 'N') 'forms.bankChargeAgreement.inactiveRow'.tr(),
          if (a.ourNumberNext != null)
            'forms.bankChargeAgreement.ourNumberRow'
                .tr(args: ['${a.ourNumberNext}']),
        ],
        // Paginação: metadados do estado montam a barra da fábrica; filtro
        // novo volta à página 1; troca de tamanho recarrega na 1.
        page: state.page,
        pageSize: state.pageSize,
        total: state.total,
        onPageChanged: (page) => _bloc
            .add(BankChargeAgreementListRequested(state.filter, page: page)),
        onPageSizeChanged: (size) => _bloc.add(
            BankChargeAgreementListRequested(state.filter, pageSize: size)),
        onFilterChanged: (filter) =>
            _bloc.add(BankChargeAgreementListRequested(filter)),
        onNew: () => _bloc.add(const BankChargeAgreementNewPressed()),
        onView: (a) => _bloc.add(BankChargeAgreementEditPressed(a.id)),
      );

  Widget _buildForm(BankChargeAgreementFormState state) =>
      _BankChargeAgreementFormView(
        key: _formViewKey,
        title: widget.title,
        state: state,
        datasource: _datasource,
        fieldConfig: fieldConfig,
        onSave: (event) => _bloc.add(event),
        onBack: () => _bloc.add(const BankChargeAgreementBackToListPressed()),
        onDelete: state.editing == null
            ? null
            : () => _bloc
                .add(BankChargeAgreementDeleteRequested(state.editing!.id)),
      );

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<BankChargeAgreementBloc, BankChargeAgreementState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is BankChargeAgreementActionSuccess ||
            current is BankChargeAgreementActionFailure,
        // PONTE de feedback (Framework de Mensagens): a tela nunca chama
        // ScaffoldMessenger/AlertDialog — sucesso = SnackBar via ponte (R1);
        // falha = dialog, com fields[] do servidor ancorado no campo do
        // formulário quando ele está montado (400 BANK_NOT_FOUND/
        // VALIDATION_FAILED em dayProtest quando protest='S').
        listener: (context, state) {
          if (state is BankChargeAgreementActionSuccess) {
            showSuccessFeedback(context, state.messageKey);
            return;
          }
          final failure = (state as BankChargeAgreementActionFailure).failure;
          final form = _formViewKey.currentState;
          if (failure.fields.isNotEmpty && form != null) {
            form.showServerFieldError(failure);
          } else {
            showFailureFeedback(context, failure);
          }
        },
        buildWhen: (_, current) =>
            current is BankChargeAgreementListState ||
            current is BankChargeAgreementFormState,
        builder: (context, state) => switch (state) {
          BankChargeAgreementFormState() => _buildForm(state),
          BankChargeAgreementListState() => _buildSearch(state),
          _ => _buildSearch(const BankChargeAgreementListState(loading: true)),
        },
      );
}

/// Taxa em % / valor monetário no formato pt-BR de exibição ("2,50").
String _formatDecimal(double? value) =>
    value == null ? '' : value.toStringAsFixed(2).replaceAll('.', ',');

/// Parse pt-BR ("2,5" / "1.234,56") → double; null quando inválido.
double? _parseDecimal(String text) =>
    double.tryParse(text.replaceAll('.', '').replaceAll(',', '.'));

const _flagYes = 'S';
const _flagNo = 'N';

/// Form da carteira de cobrança (SetesFormShell): convênio + conta
/// (lookup DEDICADO) + ativa/aceite + encargos + instrução + protesto
/// (revela dias) + próxima sequência do nosso número.
class _BankChargeAgreementFormView extends StatefulWidget {
  const _BankChargeAgreementFormView({
    required this.title,
    required this.state,
    required this.datasource,
    required this.fieldConfig,
    required this.onSave,
    required this.onBack,
    required this.onDelete,
    super.key,
  });

  final String title;
  final BankChargeAgreementFormState state;
  final BankChargeAgreementDatasource datasource;

  /// Catálogo resolvido da interface (tb_interface_has_field × cliente).
  final List<FieldConfigEntity> fieldConfig;
  final void Function(BankChargeAgreementSaveRequested event) onSave;
  final VoidCallback onBack;
  final VoidCallback? onDelete;

  @override
  State<_BankChargeAgreementFormView> createState() =>
      _BankChargeAgreementFormViewState();
}

class _BankChargeAgreementFormViewState
    extends State<_BankChargeAgreementFormView> {
  late final TextEditingController _agreement;
  late final TextEditingController _aliqInterest;
  late final TextEditingController _aliqLate;
  late final TextEditingController _valueLateMin;
  late final TextEditingController _aliqFine;
  late final TextEditingController _valueFine;
  late final TextEditingController _aliqDiscount;
  late final TextEditingController _valueRate;
  late final TextEditingController _instruction;
  late final TextEditingController _dayProtest;
  late final TextEditingController _ourNumberNext;

  // R3: foco programático + marca inline SÓ do campo pendente.
  final _focus = {
    for (final name in _fieldNames) name: FocusNode(),
  };
  final _keys = {
    for (final name in _fieldNames) name: GlobalKey<FormFieldState<String>>(),
  };

  /// Nomes do PAYLOAD (camelCase) na ordem da tela — casam com o fields[]
  /// do servidor (DTO Zod do módulo bank-charge-agreements).
  static const _fieldNames = [
    'agreement', 'aliqInterest', 'aliqLate', 'valueLateMin', 'aliqFine',
    'valueFine', 'aliqDiscount', 'valueRate', 'instruction', 'dayProtest',
    'ourNumberNext',
  ];

  /// Conta corrente escolhida no lookup — id salvo, rótulo exibido.
  int? _bankAccountId;
  String _bankAccountDisplay = '';

  /// Toggles S/N (SetesRadioGroup — fora do Tab).
  String _active = _flagYes;
  String _accept = _flagNo;
  String _protest = _flagNo;

  BankChargeAgreementFull? get _editing => widget.state.editing;

  @override
  void initState() {
    super.initState();
    final editing = _editing;
    _bankAccountId      = editing?.bankAccountId;
    _bankAccountDisplay = editing?.bankAccountDisplay ?? '';
    _active  = editing?.active ?? _flagYes;
    _accept  = editing?.accept ?? _flagNo;
    _protest = editing?.protest ?? _flagNo;

    _agreement    = TextEditingController(text: editing?.agreement ?? '');
    _aliqInterest = TextEditingController(text: _formatDecimal(editing?.aliqInterest));
    _aliqLate     = TextEditingController(text: _formatDecimal(editing?.aliqLate));
    _valueLateMin = TextEditingController(text: _formatDecimal(editing?.valueLateMin));
    _aliqFine     = TextEditingController(text: _formatDecimal(editing?.aliqFine));
    _valueFine    = TextEditingController(text: _formatDecimal(editing?.valueFine));
    _aliqDiscount = TextEditingController(text: _formatDecimal(editing?.aliqDiscount));
    _valueRate    = TextEditingController(text: _formatDecimal(editing?.valueRate));
    _instruction  = TextEditingController(text: editing?.instruction ?? '');
    _dayProtest   = TextEditingController(
        text: editing?.dayProtest == null ? '' : '${editing!.dayProtest}');
    _ourNumberNext = TextEditingController(
        text: editing?.ourNumberNext == null ? '' : '${editing!.ourNumberNext}');
  }

  @override
  void dispose() {
    _agreement.dispose();
    _aliqInterest.dispose();
    _aliqLate.dispose();
    _valueLateMin.dispose();
    _aliqFine.dispose();
    _valueFine.dispose();
    _aliqDiscount.dispose();
    _valueRate.dispose();
    _instruction.dispose();
    _dayProtest.dispose();
    _ourNumberNext.dispose();
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _pickBankAccount() async {
    final picked = await showSetesLookup<BankAccountLookup>(
      context: context,
      title: 'lookup.bankAccounts'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: widget.datasource.bankAccounts,
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
  // Catálogo de campos (seed sql/49): caption/required do cliente.
  // ------------------------------------------------------------------

  FieldConfigEntity? _cfg(String field) =>
      fieldConfigOf(widget.fieldConfig, field);

  String _label(String field, String i18nKey) =>
      _cfg(field)?.caption ?? i18nKey.tr();

  bool _requiredCfg(String field) => _cfg(field)?.required ?? false;

  // ------------------------------------------------------------------
  // Validação (R3/R6): catálogo (seed sql/49) + DTO Zod como fontes
  // (agreement 1..30, taxas 0..100, valores >= 0, instruction máx 500,
  // dayProtest obrigatório > 0 quando protest == 'S', ourNumberNext > 0).
  // ------------------------------------------------------------------

  String? _validateAgreement(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'register.requiredField'
          .tr(args: [_label('agreement', 'forms.bankChargeAgreement.agreement')]);
    }
    return text.length > 30 ? 'forms.validation.maxLength'.tr() : null;
  }

  /// Percentual OPCIONAL (0–100) — juros/mora/multa/desconto.
  String? _validatePercent(String field, String i18nKey, String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return _requiredCfg(field)
          ? 'register.requiredField'.tr(args: [_label(field, i18nKey)])
          : null;
    }
    final parsed = _parseDecimal(text);
    if (parsed == null || parsed < 0 || parsed > 100) {
      return 'forms.bankChargeAgreement.percentInvalid'.tr();
    }
    return null;
  }

  /// Valor monetário OPCIONAL (>= 0) — mora mínima/multa fixa/tarifa.
  String? _validateMoney(String field, String i18nKey, String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return _requiredCfg(field)
          ? 'register.requiredField'.tr(args: [_label(field, i18nKey)])
          : null;
    }
    final parsed = _parseDecimal(text);
    if (parsed == null || parsed < 0) {
      return 'forms.bankChargeAgreement.moneyInvalid'.tr();
    }
    return null;
  }

  String? _validateInstruction(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return _requiredCfg('instruction')
          ? 'register.requiredField'
              .tr(args: [_label('instruction', 'forms.bankChargeAgreement.instruction')])
          : null;
    }
    return text.length > 500 ? 'forms.validation.maxLength'.tr() : null;
  }

  /// Só valida quando o campo está VISÍVEL (protest == 'S' — regra do
  /// backend/DTO: obrigatório e > 0 nesse caso; escondido = sem regra).
  String? _validateDayProtest(String? value) {
    if (_protest != _flagYes) return null;
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'forms.bankChargeAgreement.dayProtestInvalid'.tr();
    }
    final parsed = int.tryParse(text);
    if (parsed == null || parsed <= 0 || parsed > 9999) {
      return 'forms.bankChargeAgreement.dayProtestInvalid'.tr();
    }
    return null;
  }

  /// Inteiro OPCIONAL positivo — próxima sequência do nosso número.
  String? _validateOurNumberNext(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return _requiredCfg('our_number_next')
          ? 'register.requiredField'.tr(args: [
              _label('our_number_next', 'forms.bankChargeAgreement.ourNumberNext')
            ])
          : null;
    }
    final parsed = int.tryParse(text);
    if (parsed == null || parsed <= 0) {
      return 'forms.bankChargeAgreement.ourNumberNextInvalid'.tr();
    }
    return null;
  }

  /// Campos NA ORDEM da tela (R3). Os names casam com o payload da API —
  /// é por eles que o fields[] do servidor ancora no campo.
  List<PendencyField> get _pendencyFields => [
        _text('agreement', () => _validateAgreement(_agreement.text)),
        PendencyField(
          name: 'bankAccountId',
          validate: () => _bankAccountId == null
              ? 'register.requiredField'.tr(args: [
                  _label('tb_bank_account_id', 'forms.bankChargeAgreement.bankAccount')
                ])
              : null,
        ),
        _text('aliqInterest', () => _validatePercent(
            'aliq_interest', 'forms.bankChargeAgreement.aliqInterest', _aliqInterest.text)),
        _text('aliqLate', () => _validatePercent(
            'aliq_late', 'forms.bankChargeAgreement.aliqLate', _aliqLate.text)),
        _text('valueLateMin', () => _validateMoney(
            'value_late_min', 'forms.bankChargeAgreement.valueLateMin', _valueLateMin.text)),
        _text('aliqFine', () => _validatePercent(
            'aliq_fine', 'forms.bankChargeAgreement.aliqFine', _aliqFine.text)),
        _text('valueFine', () => _validateMoney(
            'value_fine', 'forms.bankChargeAgreement.valueFine', _valueFine.text)),
        _text('aliqDiscount', () => _validatePercent(
            'aliq_discount', 'forms.bankChargeAgreement.aliqDiscount', _aliqDiscount.text)),
        _text('valueRate', () => _validateMoney(
            'value_rate', 'forms.bankChargeAgreement.valueRate', _valueRate.text)),
        _text('instruction', () => _validateInstruction(_instruction.text)),
        _text('dayProtest', () => _validateDayProtest(_dayProtest.text)),
        _text('ourNumberNext', () => _validateOurNumberNext(_ourNumberNext.text)),
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

  double? _decimal(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : _parseDecimal(text);
  }

  int? _integer(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : int.tryParse(text);
  }

  Future<void> _save() async {
    if (!await ensureNoPendency(context, _pendencyFields)) return;
    final instruction = _instruction.text.trim();
    widget.onSave(BankChargeAgreementSaveRequested(
      editingId: _editing?.id,
      input: BankChargeAgreementInput(
        agreement:     _agreement.text.trim(),
        bankAccountId: _bankAccountId!,
        active:        _active,
        accept:        _accept,
        aliqDiscount:  _decimal(_aliqDiscount),
        aliqInterest:  _decimal(_aliqInterest),
        aliqLate:      _decimal(_aliqLate),
        valueLateMin:  _decimal(_valueLateMin),
        aliqFine:      _decimal(_aliqFine),
        valueFine:     _decimal(_valueFine),
        valueRate:     _decimal(_valueRate),
        instruction:   instruction.isEmpty ? null : instruction,
        protest:       _protest,
        dayProtest:    _protest == _flagYes ? _integer(_dayProtest) : null,
        ourNumberNext: _integer(_ourNumberNext),
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

  /// Título de seção do grupo "Encargos" — cores SEMPRE do tema.
  Widget _sectionHeader(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
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

  List<TextInputFormatter> get _decimalFormatters => [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        LengthLimitingTextInputFormatter(12),
      ];

  @override
  Widget build(BuildContext context) {
    // Tabulação: Tab só nos campos editáveis na ordem declarada; lookup e
    // rádios ficam fora da sequência.
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
            // 1. Convênio + Conta corrente.
            field(SetesTextField(
              label: _label('agreement', 'forms.bankChargeAgreement.agreement'),
              controller: _agreement,
              focusNode: _focus['agreement'],
              fieldKey: _keys['agreement'],
              autofocus: true,
              textInputAction: TextInputAction.next,
              validator: (v) => _validateAgreement(v),
              inputFormatters: [LengthLimitingTextInputFormatter(30)],
            )),
            const SizedBox(height: 16),
            SetesLookupField(
              label: _label('tb_bank_account_id', 'forms.bankChargeAgreement.bankAccount'),
              display: _bankAccountDisplay,
              onSearch: _pickBankAccount,
              onClear: () => setState(() {
                _bankAccountId = null;
                _bankAccountDisplay = '';
              }),
            ),
            const SizedBox(height: 16),
            // 2. Ativa.
            SetesRadioGroup<String>(
              label: _label('active', 'forms.bankChargeAgreement.active'),
              helperText: 'forms.bankChargeAgreement.activeHelper'.tr(),
              value: _active,
              options: [
                SetesRadioOption(value: _flagYes, label: 'register.yes'.tr()),
                SetesRadioOption(value: _flagNo, label: 'register.no'.tr()),
              ],
              onChanged: (value) => setState(() => _active = value ?? _flagYes),
            ),
            const SizedBox(height: 16),
            // 3. Aceite do título.
            SetesRadioGroup<String>(
              label: _label('accept', 'forms.bankChargeAgreement.accept'),
              value: _accept,
              options: [
                SetesRadioOption(value: _flagYes, label: 'register.yes'.tr()),
                SetesRadioOption(value: _flagNo, label: 'register.no'.tr()),
              ],
              onChanged: (value) => setState(() => _accept = value ?? _flagNo),
            ),
            const SizedBox(height: 20),
            // 4. Encargos.
            _sectionHeader(context, 'forms.bankChargeAgreement.sectionCharges'.tr()),
            const SizedBox(height: 8),
            field(SetesTextField(
              label: _label('aliq_interest', 'forms.bankChargeAgreement.aliqInterest'),
              controller: _aliqInterest,
              focusNode: _focus['aliqInterest'],
              fieldKey: _keys['aliqInterest'],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              validator: (v) => _validatePercent(
                  'aliq_interest', 'forms.bankChargeAgreement.aliqInterest', v),
              inputFormatters: _decimalFormatters,
            )),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: field(SetesTextField(
                    label: _label('aliq_late', 'forms.bankChargeAgreement.aliqLate'),
                    controller: _aliqLate,
                    focusNode: _focus['aliqLate'],
                    fieldKey: _keys['aliqLate'],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    validator: (v) => _validatePercent(
                        'aliq_late', 'forms.bankChargeAgreement.aliqLate', v),
                    inputFormatters: _decimalFormatters,
                  )),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: field(SetesTextField(
                    label: _label('value_late_min', 'forms.bankChargeAgreement.valueLateMin'),
                    controller: _valueLateMin,
                    focusNode: _focus['valueLateMin'],
                    fieldKey: _keys['valueLateMin'],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    validator: (v) => _validateMoney(
                        'value_late_min', 'forms.bankChargeAgreement.valueLateMin', v),
                    inputFormatters: _decimalFormatters,
                  )),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: field(SetesTextField(
                    label: _label('aliq_fine', 'forms.bankChargeAgreement.aliqFine'),
                    controller: _aliqFine,
                    focusNode: _focus['aliqFine'],
                    fieldKey: _keys['aliqFine'],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    validator: (v) => _validatePercent(
                        'aliq_fine', 'forms.bankChargeAgreement.aliqFine', v),
                    inputFormatters: _decimalFormatters,
                  )),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: field(SetesTextField(
                    label: _label('value_fine', 'forms.bankChargeAgreement.valueFine'),
                    controller: _valueFine,
                    focusNode: _focus['valueFine'],
                    fieldKey: _keys['valueFine'],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    validator: (v) => _validateMoney(
                        'value_fine', 'forms.bankChargeAgreement.valueFine', v),
                    inputFormatters: _decimalFormatters,
                  )),
                ),
              ],
            ),
            const SizedBox(height: 16),
            field(SetesTextField(
              label: _label('aliq_discount', 'forms.bankChargeAgreement.aliqDiscount'),
              controller: _aliqDiscount,
              focusNode: _focus['aliqDiscount'],
              fieldKey: _keys['aliqDiscount'],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              validator: (v) => _validatePercent(
                  'aliq_discount', 'forms.bankChargeAgreement.aliqDiscount', v),
              inputFormatters: _decimalFormatters,
            )),
            const SizedBox(height: 16),
            field(SetesTextField(
              label: _label('value_rate', 'forms.bankChargeAgreement.valueRate'),
              controller: _valueRate,
              focusNode: _focus['valueRate'],
              fieldKey: _keys['valueRate'],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              validator: (v) => _validateMoney(
                  'value_rate', 'forms.bankChargeAgreement.valueRate', v),
              inputFormatters: _decimalFormatters,
            )),
            const SizedBox(height: 20),
            // 5. Instrução.
            field(SetesTextField(
              label: _label('instruction', 'forms.bankChargeAgreement.instruction'),
              hint: 'forms.bankChargeAgreement.instructionHint'.tr(),
              controller: _instruction,
              focusNode: _focus['instruction'],
              fieldKey: _keys['instruction'],
              maxLines: 3,
              textInputAction: TextInputAction.next,
              validator: (v) => _validateInstruction(v),
              inputFormatters: [LengthLimitingTextInputFormatter(500)],
            )),
            const SizedBox(height: 16),
            // 6. Protesto (revela "dias para protesto" só quando marcado).
            SetesRadioGroup<String>(
              label: _label('protest', 'forms.bankChargeAgreement.protest'),
              value: _protest,
              options: [
                SetesRadioOption(value: _flagYes, label: 'register.yes'.tr()),
                SetesRadioOption(value: _flagNo, label: 'register.no'.tr()),
              ],
              onChanged: (value) => setState(() {
                _protest = value ?? _flagNo;
                if (_protest == _flagNo) _dayProtest.clear();
              }),
            ),
            if (_protest == _flagYes) ...[
              const SizedBox(height: 16),
              field(SetesTextField(
                label: _label('day_protest', 'forms.bankChargeAgreement.dayProtest'),
                controller: _dayProtest,
                focusNode: _focus['dayProtest'],
                fieldKey: _keys['dayProtest'],
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                validator: (v) => _validateDayProtest(v),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
              )),
            ],
            const SizedBox(height: 16),
            // 7. Nosso número — próxima sequência.
            field(SetesTextField(
              label: _label('our_number_next', 'forms.bankChargeAgreement.ourNumberNext'),
              controller: _ourNumberNext,
              focusNode: _focus['ourNumberNext'],
              fieldKey: _keys['ourNumberNext'],
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              validator: (v) => _validateOurNumberNext(v),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
            )),
            _helper(context, 'forms.bankChargeAgreement.ourNumberNextHelper'.tr()),
          ],
        ),
      ),
    );
  }
}
