import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_validators/setes_validators.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/feedback/feedback.dart';
import '../../../../shared/feedback/form_pendency.dart';
import '../../../../shared/field_config/entity/field_config_entity.dart';
import '../../../../shared/field_config/field_config_loader.dart';
import '../../../../shared/field_config/field_config_of.dart';
import '../../../../shared/register/register_search_page.dart';
import '../../data/datasource/service_datasource.dart';
import '../../domain/entity/service_entity.dart';
import '../bloc/service_bloc.dart';

/// Tela de Serviços — interface 'services' (prompt_modulo_services.md,
/// D1–D7). Lista = descrição + identificador/categoria + situação. Form em
/// DUAS abas (grupos naturais): Principal (identificador, descrição,
/// categoria e plano financeiro por lookup, flags S/N, observação) e
/// Preços (GRADE: uma linha por tabela de preço viva com o valor — D4/D7;
/// a API sincroniza a tb_price na mesma transação).
///
/// Feedback 100% via PONTE (Framework de Mensagens): validação
/// uma-pendência-por-vez (R3) trocando para a aba do campo, fields[] do
/// servidor ancorado no campo (path do payload — `prices.0.priceTag`),
/// exclusão via decisão tipada (R4). Catálogo de campos aplicado pelo
/// FieldConfigLoader (caption/required/mask do cliente).
class ServicePage extends StatefulWidget {
  const ServicePage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das duas telas.
  final String title;

  @override
  State<ServicePage> createState() => _ServicePageState();
}

class _ServicePageState extends State<ServicePage> with FieldConfigLoader {
  late final ServiceBloc _bloc;
  late final ServiceDatasource _datasource;

  /// Acesso ao estado do form híbrido: ancora o fields[] do servidor no
  /// campo. O form só está montado no modo formulário.
  final _formViewKey = GlobalKey<_ServiceFormViewState>();

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<ServiceBloc>()..add(const ServiceListRequested(''));
    _datasource = Modular.get<ServiceDatasource>();
    loadFieldConfig('services'); // engine de campos configuráveis
  }

  Widget _buildSearch(ServiceListState state) =>
      RegisterSearchPage<ServiceListItem>(
        title: 'register.listTitle'.tr(args: [widget.title]),
        configModuleKey: 'services',
        items: state.items,
        loading: state.loading,
        avatarBuilder: (s) => '${s.id}',
        rowBuilder: (s) => [
          s.description,
          'forms.services.identifierRow'.tr(args: [
            s.identifier,
            s.categoryDescription ?? '',
          ]),
          s.active == 'S'
              ? 'forms.services.activeRow'.tr()
              : 'forms.services.inactiveRow'.tr(),
        ],
        page: state.page,
        pageSize: state.pageSize,
        total: state.total,
        onPageChanged: (page) =>
            _bloc.add(ServiceListRequested(state.filter, page: page)),
        onPageSizeChanged: (size) =>
            _bloc.add(ServiceListRequested(state.filter, pageSize: size)),
        onFilterChanged: (filter) => _bloc.add(ServiceListRequested(filter)),
        onNew: () => _bloc.add(const ServiceNewPressed()),
        onView: (s) => _bloc.add(ServiceEditPressed(s.id)),
      );

  Widget _buildForm(ServiceFormState state) => _ServiceFormView(
        key: _formViewKey,
        title: widget.title,
        state: state,
        datasource: _datasource,
        fieldConfig: fieldConfig,
        onSave: (event) => _bloc.add(event),
        onBack: () => _bloc.add(const ServiceBackToListPressed()),
        onDelete: state.editing == null
            ? null
            : () => _bloc.add(ServiceDeleteRequested(state.editing!.id)),
      );

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<ServiceBloc, ServiceState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is ServiceActionSuccess || current is ServiceActionFailure,
        listener: (context, state) {
          if (state is ServiceActionSuccess) {
            showSuccessFeedback(context, state.messageKey);
            return;
          }
          final failure = (state as ServiceActionFailure).failure;
          final form = _formViewKey.currentState;
          if (failure.fields.isNotEmpty && form != null) {
            form.showServerFieldError(failure);
          } else {
            showFailureFeedback(context, failure);
          }
        },
        buildWhen: (_, current) =>
            current is ServiceListState || current is ServiceFormState,
        builder: (context, state) => switch (state) {
          ServiceFormState() => _buildForm(state),
          ServiceListState() => _buildSearch(state),
          _ => _buildSearch(const ServiceListState(loading: true)),
        },
      );
}

/// Valor decimal digitado no padrão pt-BR ("1.234,56") → double
/// (null quando vazio ou inválido).
double? _parseDecimal(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  return double.tryParse(t.replaceAll('.', '').replaceAll(',', '.'));
}

/// double → texto pt-BR com 2 casas ('' para null).
String _formatDecimal(double? value) =>
    value == null ? '' : value.toStringAsFixed(2).replaceAll('.', ',');

/// Form do serviço (SetesFormShell + TabBar): Principal × Preços.
class _ServiceFormView extends StatefulWidget {
  const _ServiceFormView({
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
  final ServiceFormState state;
  final ServiceDatasource datasource;

  /// Catálogo resolvido da interface (tb_interface_has_field × cliente).
  final List<FieldConfigEntity> fieldConfig;
  final void Function(ServiceSaveRequested event) onSave;
  final VoidCallback onBack;
  final VoidCallback? onDelete;

  @override
  State<_ServiceFormView> createState() => _ServiceFormViewState();
}

class _ServiceFormViewState extends State<_ServiceFormView>
    with SingleTickerProviderStateMixin {
  static const _tabMain = 0;
  static const _tabPrices = 1;

  late final TabController _tabs = TabController(length: 2, vsync: this);

  late final TextEditingController _identifier;
  late final TextEditingController _description;
  late final TextEditingController _note;

  /// Grade de preços: uma linha por tabela viva (ordem da API); o valor
  /// digitado mora no controller da linha.
  late final List<ServicePrice> _priceRows;
  final Map<int, TextEditingController> _priceControllers = {};
  final Map<int, FocusNode> _priceFocus = {};
  final Map<int, GlobalKey<FormFieldState<String>>> _priceKeys = {};

  // R3: foco programático + marca inline SÓ do campo pendente.
  final _focus = {for (final name in _fieldNames) name: FocusNode()};
  final _keys = {
    for (final name in _fieldNames) name: GlobalKey<FormFieldState<String>>(),
  };

  /// Nomes do PAYLOAD (camelCase) dos campos de texto — casam com o
  /// fields[] do servidor (DTO Zod do módulo services).
  static const _fieldNames = ['identifier', 'description', 'note'];

  /// Lookups — id salvo, descrição exibida.
  int? _categoryId;
  String _categoryDisplay = '';
  int? _financialPlansId;
  String _financialPlansDisplay = '';

  /// Flags S/N (D2: todas expostas).
  String _active = 'S';
  String _promotion = 'N';
  String _highlights = 'N';
  String _published = 'N';

  ServiceFull? get _editing => widget.state.editing;

  @override
  void initState() {
    super.initState();
    final editing = _editing;
    _identifier  = TextEditingController(text: editing?.identifier ?? '');
    _description = TextEditingController(text: editing?.description ?? '');
    _note        = TextEditingController(text: editing?.note ?? '');
    _categoryId             = editing?.categoryId;
    _categoryDisplay        = editing?.categoryDescription ?? '';
    _financialPlansId       = editing?.financialPlansId;
    _financialPlansDisplay  = editing?.financialPlansDescription ?? '';
    _active     = editing?.active ?? 'S';
    _promotion  = editing?.promotion ?? 'N';
    _highlights = editing?.highlights ?? 'N';
    _published  = editing?.published ?? 'N';

    _priceRows = widget.state.prices;
    for (final row in _priceRows) {
      _priceControllers[row.priceListId] =
          TextEditingController(text: _formatDecimal(row.priceTag));
      _priceFocus[row.priceListId] = FocusNode();
      _priceKeys[row.priceListId] = GlobalKey<FormFieldState<String>>();
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _identifier.dispose();
    _description.dispose();
    _note.dispose();
    for (final node in _focus.values) {
      node.dispose();
    }
    for (final controller in _priceControllers.values) {
      controller.dispose();
    }
    for (final node in _priceFocus.values) {
      node.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Lookups (skill campo-lookup-fk.md): usuário nunca digita id.
  // ------------------------------------------------------------------

  Future<void> _pickCategory() async {
    final picked = await showSetesLookup<ServiceLookup>(
      context: context,
      title: 'lookup.categories'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: widget.datasource.categories,
      itemId: (c) => c.id,
      itemLabel: (c) => c.display,
    );
    if (picked != null) {
      setState(() {
        _categoryId = picked.id;
        _categoryDisplay = picked.display;
      });
    }
  }

  Future<void> _pickFinancialPlan() async {
    final picked = await showSetesLookup<ServiceLookup>(
      context: context,
      title: 'lookup.financialPlans'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: widget.datasource.financialPlans,
      itemId: (f) => f.id,
      itemLabel: (f) => f.display,
    );
    if (picked != null) {
      setState(() {
        _financialPlansId = picked.id;
        _financialPlansDisplay = picked.display;
      });
    }
  }

  // ------------------------------------------------------------------
  // Catálogo de campos: caption/required/mask do cliente.
  // ------------------------------------------------------------------

  FieldConfigEntity? _cfg(String field) =>
      fieldConfigOf(widget.fieldConfig, field);

  String _label(String field, String i18nKey) =>
      _cfg(field)?.caption ?? i18nKey.tr();

  bool _requiredCfg(String field) => _cfg(field)?.required ?? false;

  List<TextInputFormatter> _formatters(
      String field, TextInputFormatter fallback) {
    final mask = _cfg(field)?.mask;
    return [mask == null ? fallback : SetesMaskFormatter(mask)];
  }

  String? _maskError(String field, String text) {
    final mask = _cfg(field)?.mask;
    if (mask == null || text.isEmpty) return null;
    return matchesMask(mask, text) ? null : 'forms.validation.mask'.tr();
  }

  String _unmasked(String field, TextEditingController controller) {
    final text = controller.text.trim();
    return _cfg(field)?.mask == null ? text : unmask(text);
  }

  String? _optionalUnmasked(String field, TextEditingController controller) {
    final text = _unmasked(field, controller);
    return text.isEmpty ? null : text;
  }

  // ------------------------------------------------------------------
  // Validação (R3/R6): DTO Zod (identifier ≤50 opcional, description
  // 1..100, categoryId obrigatório, note ≤4000, priceTag ≥ 0 ou null) +
  // catálogo do cliente.
  // ------------------------------------------------------------------

  String? _validateRequiredText(String field, String i18nKey, String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'register.requiredField'.tr(args: [_label(field, i18nKey)]);
    }
    return _maskError(field, text);
  }

  String? _validateOptionalText(String field, String i18nKey, String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return _requiredCfg(field)
          ? 'register.requiredField'.tr(args: [_label(field, i18nKey)])
          : null;
    }
    return _maskError(field, text);
  }

  /// Preço da grade: vazio = sem preço (ok); preenchido = decimal ≥ 0.
  String? _validatePrice(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = _parseDecimal(text);
    return parsed == null || parsed < 0
        ? 'forms.services.priceInvalid'.tr()
        : null;
  }

  void _toMain() => _tabs.animateTo(_tabMain);
  void _toPrices() => _tabs.animateTo(_tabPrices);

  /// Campos NA ORDEM da tela (R3). Os names casam com o payload da API —
  /// é por eles que o fields[] do servidor ancora no campo; cada campo
  /// troca para a própria aba antes do foco.
  List<PendencyField> get _pendencyFields => [
        _text('identifier', _toMain, () => _validateOptionalText(
            'identifier', 'forms.services.identifier', _identifier.text)),
        _text('description', _toMain, () => _validateRequiredText(
            'description', 'forms.services.description', _description.text)),
        PendencyField(
          name: 'categoryId',
          beforeFocus: _toMain,
          validate: () => _categoryId == null
              ? 'register.requiredField'.tr(
                  args: [_label('tb_category_id', 'forms.services.category')])
              : null,
        ),
        PendencyField(
          name: 'financialPlansId',
          beforeFocus: _toMain,
          validate: () => _financialPlansId == null &&
                  _requiredCfg('tb_financial_plans_id')
              ? 'register.requiredField'.tr(args: [
                  _label('tb_financial_plans_id',
                      'forms.services.financialPlan')
                ])
              : null,
        ),
        PendencyField(name: 'active', beforeFocus: _toMain, validate: () => null),
        PendencyField(
            name: 'promotion', beforeFocus: _toMain, validate: () => null),
        PendencyField(
            name: 'highlights', beforeFocus: _toMain, validate: () => null),
        PendencyField(
            name: 'published', beforeFocus: _toMain, validate: () => null),
        _text('note', _toMain, () => _validateOptionalText(
            'note', 'forms.services.note', _note.text)),
        // Grade: path do payload (`prices.<i>.priceTag`) casa EXATO com o
        // fields[] do Zod; 'prices' pega o refine (tabela duplicada) e a
        // checagem de FK da API.
        for (var i = 0; i < _priceRows.length; i++)
          PendencyField(
            name: 'prices.$i.priceTag',
            beforeFocus: _toPrices,
            focusNode: _priceFocus[_priceRows[i].priceListId],
            fieldKey: _priceKeys[_priceRows[i].priceListId],
            validate: () => _validatePrice(
                _priceControllers[_priceRows[i].priceListId]!.text),
          ),
        PendencyField(
            name: 'prices', beforeFocus: _toPrices, validate: () => null),
      ];

  PendencyField _text(
          String name, VoidCallback beforeFocus, String? Function() validate) =>
      PendencyField(
        name: name,
        beforeFocus: beforeFocus,
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
    widget.onSave(ServiceSaveRequested(
      editingId: _editing?.id,
      input: ServiceInput(
        identifier:       _optionalUnmasked('identifier', _identifier),
        description:      _unmasked('description', _description),
        categoryId:       _categoryId!,
        financialPlansId: _financialPlansId,
        promotion:        _promotion,
        highlights:       _highlights,
        published:        _published,
        active:           _active,
        note:             _optionalUnmasked('note', _note),
        // TODAS as linhas da grade viajam (priceTag null = a API remove).
        prices: [
          for (final row in _priceRows)
            ServicePriceInput(
              priceListId: row.priceListId,
              priceTag: _parseDecimal(
                  _priceControllers[row.priceListId]!.text),
            ),
        ],
      ),
    ));
  }

  /// Exclusão confirmada via decisão TIPADA da ponte (R4).
  Future<void> _confirmDelete() async {
    final decision = await askDecision(
      context,
      message: 'register.confirmDelete'.tr(),
      yesLabel: 'register.delete'.tr(),
    );
    if (decision == SetesDecision.yes) widget.onDelete?.call();
  }

  Widget _snRadio(String field, String i18nKey, String value,
          ValueChanged<String> onChanged) =>
      SetesRadioGroup<String>(
        label: _label(field, i18nKey),
        value: value,
        options: [
          SetesRadioOption(value: 'S', label: 'register.yes'.tr()),
          SetesRadioOption(value: 'N', label: 'register.no'.tr()),
        ],
        onChanged: (v) => onChanged(v ?? 'N'),
      );

  Widget _buildMainTab() {
    // Tabulação: Tab só nos campos editáveis na ordem declarada; lookups
    // e radios ficam fora da sequência.
    var order = 0;
    Widget field(Widget child) => FocusTraversalOrder(
        order: NumericFocusOrder((++order).toDouble()), child: child);

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          field(SetesTextField(
            label: _label('identifier', 'forms.services.identifier'),
            hint: 'forms.services.identifierHint'.tr(),
            controller: _identifier,
            focusNode: _focus['identifier'],
            fieldKey: _keys['identifier'],
            autofocus: true,
            textInputAction: TextInputAction.next,
            validator: (v) => _validateOptionalText(
                'identifier', 'forms.services.identifier', v),
            inputFormatters: _formatters(
                'identifier', LengthLimitingTextInputFormatter(50)),
          )),
          const SizedBox(height: 16),
          field(SetesTextField(
            label: _label('description', 'forms.services.description'),
            controller: _description,
            focusNode: _focus['description'],
            fieldKey: _keys['description'],
            textInputAction: TextInputAction.next,
            validator: (v) => _validateRequiredText(
                'description', 'forms.services.description', v),
            inputFormatters: _formatters(
                'description', LengthLimitingTextInputFormatter(100)),
          )),
          const SizedBox(height: 16),
          SetesLookupField(
            label: _label('tb_category_id', 'forms.services.category'),
            display: _categoryDisplay,
            onSearch: _pickCategory,
          ),
          const SizedBox(height: 16),
          SetesLookupField(
            label: _label(
                'tb_financial_plans_id', 'forms.services.financialPlan'),
            display: _financialPlansDisplay,
            onSearch: _pickFinancialPlan,
            onClear: () => setState(() {
              _financialPlansId = null;
              _financialPlansDisplay = '';
            }),
          ),
          const SizedBox(height: 16),
          _snRadio('active', 'forms.services.active', _active,
              (v) => setState(() => _active = v)),
          const SizedBox(height: 16),
          _snRadio('promotion', 'forms.services.promotion', _promotion,
              (v) => setState(() => _promotion = v)),
          const SizedBox(height: 16),
          _snRadio('highlights', 'forms.services.highlights', _highlights,
              (v) => setState(() => _highlights = v)),
          const SizedBox(height: 16),
          _snRadio('published', 'forms.services.published', _published,
              (v) => setState(() => _published = v)),
          const SizedBox(height: 16),
          field(SetesTextField(
            label: _label('note', 'forms.services.note'),
            controller: _note,
            focusNode: _focus['note'],
            fieldKey: _keys['note'],
            maxLines: 4,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            validator: (v) =>
                _validateOptionalText('note', 'forms.services.note', v),
            inputFormatters: _formatters(
                'note', LengthLimitingTextInputFormatter(4000)),
          )),
        ],
      ),
    );
  }

  /// Grade de preços (D4/D7): uma linha por tabela de preço viva, valor
  /// decimal editável; vazio = sem preço nessa tabela.
  Widget _buildPricesTab() {
    if (_priceRows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SetesText('forms.services.noPriceLists'.tr()),
        ),
      );
    }
    var order = 0;
    Widget field(Widget child) => FocusTraversalOrder(
        order: NumericFocusOrder((++order).toDouble()), child: child);

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _priceRows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final row = _priceRows[i];
          final last = i == _priceRows.length - 1;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(child: SetesText('${row.priceListId}')),
              const SizedBox(width: 12),
              Expanded(
                child: SetesText(row.priceListDescription ?? ''),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 180,
                child: field(SetesTextField(
                  label: 'forms.services.priceTag'.tr(),
                  controller: _priceControllers[row.priceListId],
                  focusNode: _priceFocus[row.priceListId],
                  fieldKey: _priceKeys[row.priceListId],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction:
                      last ? TextInputAction.done : TextInputAction.next,
                  validator: _validatePrice,
                )),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SetesFormShell(
        title: widget.title,
        saving: widget.state.saving,
        onBack: widget.onBack,
        onSave: _save,
        onDelete: widget.onDelete != null ? _confirmDelete : null,
        child: Column(
          children: [
            TabBar(
              controller: _tabs,
              tabs: [
                Tab(text: 'forms.services.tabMain'.tr()),
                Tab(text: 'forms.services.tabPrices'.tr()),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _buildMainTab(),
                  _buildPricesTab(),
                ],
              ),
            ),
          ],
        ),
      );
}
