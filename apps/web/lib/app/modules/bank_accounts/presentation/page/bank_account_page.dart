import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_validators/setes_validators.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/entity/widgets/entity_date.dart';
import '../../../../shared/feedback/feedback.dart';
import '../../../../shared/feedback/form_pendency.dart';
import '../../../../shared/field_config/entity/field_config_entity.dart';
import '../../../../shared/field_config/field_config_loader.dart';
import '../../../../shared/field_config/field_config_of.dart';
import '../../../../shared/register/register_search_page.dart';
import '../../data/datasource/bank_account_datasource.dart';
import '../../domain/entity/bank_account_entity.dart';
import '../bloc/bank_account_bloc.dart';

/// Tela de Contas Bancárias — interface 'bank-accounts', grupo Financeiro
/// (Módulo Software House, seção 5.6 do prompt fechado).
///
/// Lista = contas da institution com banco (catálogo central FEBRABAN),
/// agência/conta e gerente. Form = banco (lookup /api/bank-accounts/banks),
/// agência + DV e conta + DV lado a lado, datas de abertura/contrato,
/// telefone, gerente e limite.
///
/// Feedback 100% via PONTE (Framework de Mensagens, Onda B): validação
/// uma-pendência-por-vez (R3), fields[] do servidor ancorado no campo,
/// exclusão via decisão tipada (R4). Catálogo de campos (seed sql/17)
/// aplicado pelo FieldConfigLoader (caption/required/mask do cliente).
class BankAccountPage extends StatefulWidget {
  const BankAccountPage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das duas telas.
  final String title;

  @override
  State<BankAccountPage> createState() => _BankAccountPageState();
}

class _BankAccountPageState extends State<BankAccountPage>
    with FieldConfigLoader {
  late final BankAccountBloc _bloc;
  late final BankAccountDatasource _datasource;

  /// Acesso ao estado do form híbrido: ancora o fields[] do servidor no
  /// campo (equivalente local do showServerFieldError da fábrica). O form
  /// só está montado no modo formulário — na lista o currentState é null.
  final _formViewKey = GlobalKey<_BankAccountFormViewState>();

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<BankAccountBloc>()
      ..add(const BankAccountListRequested('', refresh: true));
    _datasource = Modular.get<BankAccountDatasource>();
    loadFieldConfig('bank-accounts'); // engine de campos configuráveis (dec. 7)
  }

  Widget _buildSearch(BankAccountListState state) =>
      RegisterSearchPage<BankAccountListItem>(
        title: 'register.listTitle'.tr(args: [widget.title]),
        // Engrenagem padrão da lista (Framework de Configurações, decisão 11)
        configModuleKey: 'bank-accounts',
        items: state.items,
        loading: state.loading,
        avatarBuilder: (a) =>
            (a.bankNumber != null && a.bankNumber!.isNotEmpty)
                ? a.bankNumber!
                : '${a.id}',
        rowBuilder: (a) => [
          a.bankDisplay,
          'forms.bankAccount.accountRow'
              .tr(args: [a.agencyDisplay, a.numberDisplay]),
          if (a.manager != null && a.manager!.isNotEmpty)
            'forms.bankAccount.managerRow'.tr(args: [a.manager!]),
        ],
        onFilterChanged: (filter) => _bloc.add(BankAccountListRequested(filter)),
        onNew: () => _bloc.add(const BankAccountNewPressed()),
        onView: (a) => _bloc.add(BankAccountEditPressed(a.id)),
      );

  Widget _buildForm(BankAccountFormState state) => _BankAccountFormView(
        key: _formViewKey,
        title: widget.title,
        state: state,
        datasource: _datasource,
        fieldConfig: fieldConfig,
        onSave: (event) => _bloc.add(event),
        onBack: () => _bloc.add(const BankAccountBackToListPressed()),
        onDelete: state.editing == null
            ? null
            : () => _bloc.add(BankAccountDeleteRequested(state.editing!.id)),
      );

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<BankAccountBloc, BankAccountState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is BankAccountActionSuccess ||
            current is BankAccountActionFailure,
        // PONTE de feedback (Framework de Mensagens): a tela nunca chama
        // ScaffoldMessenger/AlertDialog — sucesso = SnackBar via ponte (R1);
        // falha = dialog, com fields[] do servidor ancorado no campo do
        // formulário quando ele está montado.
        listener: (context, state) {
          if (state is BankAccountActionSuccess) {
            showSuccessFeedback(context, state.messageKey);
            return;
          }
          final failure = (state as BankAccountActionFailure).failure;
          final form = _formViewKey.currentState;
          if (failure.fields.isNotEmpty && form != null) {
            form.showServerFieldError(failure);
          } else {
            showFailureFeedback(context, failure);
          }
        },
        buildWhen: (_, current) =>
            current is BankAccountListState || current is BankAccountFormState,
        builder: (context, state) => switch (state) {
          BankAccountFormState() => _buildForm(state),
          BankAccountListState() => _buildSearch(state),
          _ => _buildSearch(const BankAccountListState(loading: true)),
        },
      );
}

/// Form da conta bancária (SetesFormShell): banco (lookup do catálogo
/// central FEBRABAN) + agência/DV e conta/DV lado a lado + datas +
/// telefone + gerente + limite.
class _BankAccountFormView extends StatefulWidget {
  const _BankAccountFormView({
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
  final BankAccountFormState state;
  final BankAccountDatasource datasource;

  /// Catálogo resolvido da interface (tb_interface_has_field × cliente).
  final List<FieldConfigEntity> fieldConfig;
  final void Function(BankAccountSaveRequested event) onSave;
  final VoidCallback onBack;
  final VoidCallback? onDelete;

  @override
  State<_BankAccountFormView> createState() => _BankAccountFormViewState();
}

class _BankAccountFormViewState extends State<_BankAccountFormView> {
  late final TextEditingController _agency;
  late final TextEditingController _agencyDv;
  late final TextEditingController _number;
  late final TextEditingController _numberDv;
  late final TextEditingController _dtOpening;
  late final TextEditingController _phone;
  late final TextEditingController _manager;
  late final TextEditingController _limitValue;
  late final TextEditingController _dtContract;

  // R3: foco programático + marca inline SÓ do campo pendente.
  final _focus = {
    for (final name in _fieldNames) name: FocusNode(),
  };
  final _keys = {
    for (final name in _fieldNames) name: GlobalKey<FormFieldState<String>>(),
  };

  /// Nomes do PAYLOAD (camelCase) na ordem da tela — casam com o fields[]
  /// do servidor (DTO Zod do módulo bank-accounts).
  static const _fieldNames = [
    'agency', 'agencyDv', 'number', 'numberDv', 'dtOpening',
    'phone', 'manager', 'limitValue', 'dtContract',
  ];

  /// Banco escolhido no lookup — id salvo, "número - descrição" exibido.
  int? _bankId;
  String _bankDisplay = '';

  BankAccountFull? get _editing => widget.state.editing;

  @override
  void initState() {
    super.initState();
    final editing = _editing;
    _bankId      = editing?.bankId;
    _bankDisplay = editing?.bankDisplay ?? '';
    _agency     = TextEditingController(text: editing?.agency ?? '');
    _agencyDv   = TextEditingController(text: editing?.agencyDv ?? '');
    _number     = TextEditingController(text: editing?.number ?? '');
    _numberDv   = TextEditingController(text: editing?.numberDv ?? '');
    _dtOpening  = TextEditingController(text: isoDateToDisplay(editing?.dtOpening));
    _phone      = TextEditingController(text: editing?.phone ?? '');
    _manager    = TextEditingController(text: editing?.manager ?? '');
    _limitValue = TextEditingController(
        text: editing?.limitValue == null
            ? ''
            : editing!.limitValue!.toStringAsFixed(2).replaceAll('.', ','));
    _dtContract = TextEditingController(text: isoDateToDisplay(editing?.dtContract));
  }

  @override
  void dispose() {
    _agency.dispose();
    _agencyDv.dispose();
    _number.dispose();
    _numberDv.dispose();
    _dtOpening.dispose();
    _phone.dispose();
    _manager.dispose();
    _limitValue.dispose();
    _dtContract.dispose();
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _pickBank() async {
    final picked = await showSetesLookup<BankLookup>(
      context: context,
      title: 'lookup.banks'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: widget.datasource.banks,
      itemId: (b) => b.id,
      itemLabel: (b) => b.display,
    );
    if (picked != null) {
      setState(() {
        _bankId      = picked.id;
        _bankDisplay = picked.display;
      });
    }
  }

  // ------------------------------------------------------------------
  // Catálogo de campos (decisão 7): caption/required/mask do cliente.
  // ------------------------------------------------------------------

  FieldConfigEntity? _cfg(String field) =>
      fieldConfigOf(widget.fieldConfig, field);

  String _label(String field, String i18nKey) =>
      _cfg(field)?.caption ?? i18nKey.tr();

  bool _requiredCfg(String field) => _cfg(field)?.required ?? false;

  /// Formatter: máscara custom do cliente substitui o limitador default
  /// (campos String do catálogo — decisão 16).
  List<TextInputFormatter> _formatters(
      String field, TextInputFormatter fallback) {
    final mask = _cfg(field)?.mask;
    return [mask == null ? fallback : SetesMaskFormatter(mask)];
  }

  /// Valor preenchido precisa CASAR com a máscara custom (se houver).
  String? _maskError(String field, String text) {
    final mask = _cfg(field)?.mask;
    if (mask == null || text.isEmpty) return null;
    return matchesMask(mask, text) ? null : 'forms.validation.mask'.tr();
  }

  /// Decisão 19: campo mascarado grava só o que o usuário digitou.
  String _unmasked(String field, TextEditingController controller) {
    final text = controller.text.trim();
    return _cfg(field)?.mask == null ? text : unmask(text);
  }

  /// null limpo: '' vira null (a API aceita nullable).
  String? _optionalUnmasked(String field, TextEditingController controller) {
    final text = _unmasked(field, controller);
    return text.isEmpty ? null : text;
  }

  // ------------------------------------------------------------------
  // Validação (R3/R6): catálogo (seed sql/17) + DTO Zod como fontes; os
  // validators servem o inline (SetesTextField) E a cadeia do salvar.
  // ------------------------------------------------------------------

  /// Texto OBRIGATÓRIO pelo baseline técnico (agency/number).
  String? _validateRequiredText(String field, String i18nKey, String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'register.requiredField'.tr(args: [_label(field, i18nKey)]);
    }
    return _maskError(field, text);
  }

  /// Texto OPCIONAL — cliente pode apertar (required) e mascarar.
  String? _validateOptionalText(String field, String i18nKey, String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return _requiredCfg(field)
          ? 'register.requiredField'.tr(args: [_label(field, i18nKey)])
          : null;
    }
    return _maskError(field, text);
  }

  /// Data OPCIONAL — cliente pode apertar (required); formato é do código.
  String? _validateOptionalDateCfg(
      String field, String i18nKey, String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return _requiredCfg(field)
          ? 'register.requiredField'.tr(args: [_label(field, i18nKey)])
          : null;
    }
    return displayDateToIso(text) == null ? 'register.invalidDate'.tr() : null;
  }

  /// Limite: parse pt-BR ("1.234,56"), >= 0 quando preenchido.
  String? _validateLimit(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return _requiredCfg('limit_value')
          ? 'register.requiredField'.tr(
              args: [_label('limit_value', 'forms.bankAccount.limitValue')])
          : null;
    }
    final parsed =
        double.tryParse(text.replaceAll('.', '').replaceAll(',', '.'));
    if (parsed == null || parsed < 0) {
      return 'forms.bankAccount.limitInvalid'.tr();
    }
    return null;
  }

  /// Campos NA ORDEM da tela (R3). Os names casam com o payload da API —
  /// é por eles que o fields[] do servidor ancora no campo.
  List<PendencyField> get _pendencyFields => [
        PendencyField(
          name: 'bankId',
          validate: () => _bankId == null
              ? 'register.requiredField'
                  .tr(args: [_label('tb_bank_id', 'forms.bankAccount.bank')])
              : null,
        ),
        _text('agency', () => _validateRequiredText(
            'agency', 'forms.bankAccount.agency', _agency.text)),
        _text('agencyDv', () => _validateOptionalText(
            'agency_dv', 'forms.bankAccount.agencyDv', _agencyDv.text)),
        _text('number', () => _validateRequiredText(
            'number', 'forms.bankAccount.number', _number.text)),
        _text('numberDv', () => _validateOptionalText(
            'number_dv', 'forms.bankAccount.numberDv', _numberDv.text)),
        _text('dtOpening', () => _validateOptionalDateCfg(
            'dt_opening', 'forms.bankAccount.dtOpening', _dtOpening.text)),
        _text('phone', () => _validateOptionalText(
            'phone', 'forms.bankAccount.phone', _phone.text)),
        _text('manager', () => _validateOptionalText(
            'manager', 'forms.bankAccount.manager', _manager.text)),
        _text('limitValue', () => _validateLimit(_limitValue.text)),
        _text('dtContract', () => _validateOptionalDateCfg(
            'dt_contract', 'forms.bankAccount.dtContract', _dtContract.text)),
      ];

  PendencyField _text(String name, String? Function() validate) =>
      PendencyField(
        name: name,
        focusNode: _focus[name],
        fieldKey: _keys[name],
        validate: validate,
      );

  /// Ancora o fields[] do envelope 400/409 no campo (chamado pelo listener
  /// do bloc via GlobalKey — equivalente local da fábrica).
  Future<void> showServerFieldError(Failure failure) =>
      showServerFieldFeedback(context, failure, _pendencyFields);

  Future<void> _save() async {
    if (!await ensureNoPendency(context, _pendencyFields)) return;
    final limitText = _limitValue.text.trim();
    widget.onSave(BankAccountSaveRequested(
      editingId: _editing?.id,
      input: BankAccountInput(
        bankId:     _bankId!,
        agency:     _unmasked('agency', _agency),
        agencyDv:   _optionalUnmasked('agency_dv', _agencyDv),
        number:     _unmasked('number', _number),
        numberDv:   _optionalUnmasked('number_dv', _numberDv),
        dtOpening:  displayDateToIso(_dtOpening.text),
        phone:      _optionalUnmasked('phone', _phone),
        manager:    _optionalUnmasked('manager', _manager),
        limitValue: limitText.isEmpty
            ? null
            : double.parse(
                limitText.replaceAll('.', '').replaceAll(',', '.')),
        dtContract: displayDateToIso(_dtContract.text),
      ),
    ));
  }

  /// Exclusão confirmada via decisão TIPADA da ponte (R4): Sim = excluir;
  /// Cancelar (ou fechar) = nada. Sem ação alternativa → sem botão Não.
  Future<void> _confirmDelete() async {
    final decision = await askDecision(
      context,
      message: 'register.confirmDelete'.tr(),
      yesLabel: 'register.delete'.tr(),
    );
    if (decision == SetesDecision.yes) widget.onDelete?.call();
  }

  @override
  Widget build(BuildContext context) {
    // Tabulação (criar-formulario-cadastro.md, item 8): Tab só nos campos
    // editáveis na ordem declarada; o lookup fica fora da sequência.
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
            SetesLookupField(
              label: _label('tb_bank_id', 'forms.bankAccount.bank'),
              display: _bankDisplay,
              onSearch: _pickBank,
              onClear: () => setState(() {
                _bankId = null;
                _bankDisplay = '';
              }),
            ),
            const SizedBox(height: 16),
            // Agência + DV lado a lado (DV curto).
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: field(SetesTextField(
                    label: _label('agency', 'forms.bankAccount.agency'),
                    controller: _agency,
                    focusNode: _focus['agency'],
                    fieldKey: _keys['agency'],
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    validator: (v) => _validateRequiredText(
                        'agency', 'forms.bankAccount.agency', v),
                    inputFormatters: _formatters(
                        'agency', LengthLimitingTextInputFormatter(8)),
                  )),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: field(SetesTextField(
                    label: _label('agency_dv', 'forms.bankAccount.agencyDv'),
                    controller: _agencyDv,
                    focusNode: _focus['agencyDv'],
                    fieldKey: _keys['agencyDv'],
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    validator: (v) => _validateOptionalText(
                        'agency_dv', 'forms.bankAccount.agencyDv', v),
                    inputFormatters: _formatters(
                        'agency_dv', LengthLimitingTextInputFormatter(2)),
                  )),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Conta + DV lado a lado (DV curto).
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: field(SetesTextField(
                    label: _label('number', 'forms.bankAccount.number'),
                    controller: _number,
                    focusNode: _focus['number'],
                    fieldKey: _keys['number'],
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    validator: (v) => _validateRequiredText(
                        'number', 'forms.bankAccount.number', v),
                    inputFormatters: _formatters(
                        'number', LengthLimitingTextInputFormatter(10)),
                  )),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: field(SetesTextField(
                    label: _label('number_dv', 'forms.bankAccount.numberDv'),
                    controller: _numberDv,
                    focusNode: _focus['numberDv'],
                    fieldKey: _keys['numberDv'],
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    validator: (v) => _validateOptionalText(
                        'number_dv', 'forms.bankAccount.numberDv', v),
                    inputFormatters: _formatters(
                        'number_dv', LengthLimitingTextInputFormatter(2)),
                  )),
                ),
              ],
            ),
            const SizedBox(height: 16),
            field(SetesTextField(
              label: _label('dt_opening', 'forms.bankAccount.dtOpening'),
              hint: 'register.dateHint'.tr(),
              controller: _dtOpening,
              focusNode: _focus['dtOpening'],
              fieldKey: _keys['dtOpening'],
              textInputAction: TextInputAction.next,
              validator: (v) => _validateOptionalDateCfg(
                  'dt_opening', 'forms.bankAccount.dtOpening', v),
            )),
            const SizedBox(height: 16),
            field(SetesTextField(
              label: _label('phone', 'forms.bankAccount.phone'),
              controller: _phone,
              focusNode: _focus['phone'],
              fieldKey: _keys['phone'],
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: (v) => _validateOptionalText(
                  'phone', 'forms.bankAccount.phone', v),
              inputFormatters: _formatters(
                  'phone', LengthLimitingTextInputFormatter(10)),
            )),
            const SizedBox(height: 16),
            field(SetesTextField(
              label: _label('manager', 'forms.bankAccount.manager'),
              controller: _manager,
              focusNode: _focus['manager'],
              fieldKey: _keys['manager'],
              textInputAction: TextInputAction.next,
              validator: (v) => _validateOptionalText(
                  'manager', 'forms.bankAccount.manager', v),
              inputFormatters: _formatters(
                  'manager', LengthLimitingTextInputFormatter(25)),
            )),
            const SizedBox(height: 16),
            field(SetesTextField(
              label: _label('limit_value', 'forms.bankAccount.limitValue'),
              controller: _limitValue,
              focusNode: _focus['limitValue'],
              fieldKey: _keys['limitValue'],
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              validator: _validateLimit,
            )),
            const SizedBox(height: 16),
            field(SetesTextField(
              label: _label('dt_contract', 'forms.bankAccount.dtContract'),
              hint: 'register.dateHint'.tr(),
              controller: _dtContract,
              focusNode: _focus['dtContract'],
              fieldKey: _keys['dtContract'],
              textInputAction: TextInputAction.done,
              validator: (v) => _validateOptionalDateCfg(
                  'dt_contract', 'forms.bankAccount.dtContract', v),
            )),
          ],
        ),
      ),
    );
  }
}
