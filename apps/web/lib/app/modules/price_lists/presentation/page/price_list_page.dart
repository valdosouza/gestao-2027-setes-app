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
import '../../domain/entity/price_list_entity.dart';
import '../bloc/price_list_bloc.dart';

/// Tela de Tabelas de Preço — interface 'price-lists' (D7 do
/// prompt_modulo_services.md). Lista = descrição + vigência; form =
/// descrição, vigência, modalidade e publicada (coluna única — poucos
/// campos sem agrupamento natural).
///
/// Feedback 100% via PONTE (Framework de Mensagens): validação
/// uma-pendência-por-vez (R3), fields[] do servidor ancorado no campo,
/// exclusão via decisão tipada (R4). Catálogo de campos aplicado pelo
/// FieldConfigLoader (caption/required/mask do cliente).
class PriceListPage extends StatefulWidget {
  const PriceListPage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das duas telas.
  final String title;

  @override
  State<PriceListPage> createState() => _PriceListPageState();
}

class _PriceListPageState extends State<PriceListPage> with FieldConfigLoader {
  late final PriceListBloc _bloc;

  /// Acesso ao estado do form híbrido: ancora o fields[] do servidor no
  /// campo. O form só está montado no modo formulário.
  final _formViewKey = GlobalKey<_PriceListFormViewState>();

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<PriceListBloc>()
      ..add(const PriceListListRequested(''));
    loadFieldConfig('price-lists'); // engine de campos configuráveis
  }

  Widget _buildSearch(PriceListListState state) =>
      RegisterSearchPage<PriceListEntity>(
        title: 'register.listTitle'.tr(args: [widget.title]),
        configModuleKey: 'price-lists',
        items: state.items,
        loading: state.loading,
        avatarBuilder: (p) => '${p.id}',
        rowBuilder: (p) => [
          p.description,
          if (p.validity != null && p.validity!.isNotEmpty)
            'forms.priceLists.validityRow'
                .tr(args: [isoDateToDisplay(p.validity)]),
        ],
        page: state.page,
        pageSize: state.pageSize,
        total: state.total,
        onPageChanged: (page) =>
            _bloc.add(PriceListListRequested(state.filter, page: page)),
        onPageSizeChanged: (size) =>
            _bloc.add(PriceListListRequested(state.filter, pageSize: size)),
        onFilterChanged: (filter) => _bloc.add(PriceListListRequested(filter)),
        onNew: () => _bloc.add(const PriceListNewPressed()),
        onView: (p) => _bloc.add(PriceListEditPressed(p.id)),
      );

  Widget _buildForm(PriceListFormState state) => _PriceListFormView(
        key: _formViewKey,
        title: widget.title,
        state: state,
        fieldConfig: fieldConfig,
        onSave: (event) => _bloc.add(event),
        onBack: () => _bloc.add(const PriceListBackToListPressed()),
        onDelete: state.editing == null
            ? null
            : () => _bloc.add(PriceListDeleteRequested(state.editing!.id)),
      );

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<PriceListBloc, PriceListState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is PriceListActionSuccess ||
            current is PriceListActionFailure,
        listener: (context, state) {
          if (state is PriceListActionSuccess) {
            showSuccessFeedback(context, state.messageKey);
            return;
          }
          final failure = (state as PriceListActionFailure).failure;
          final form = _formViewKey.currentState;
          if (failure.fields.isNotEmpty && form != null) {
            form.showServerFieldError(failure);
          } else {
            showFailureFeedback(context, failure);
          }
        },
        buildWhen: (_, current) =>
            current is PriceListListState || current is PriceListFormState,
        builder: (context, state) => switch (state) {
          PriceListFormState() => _buildForm(state),
          PriceListListState() => _buildSearch(state),
          _ => _buildSearch(const PriceListListState(loading: true)),
        },
      );
}

/// Form da tabela de preço (SetesFormShell, coluna única).
class _PriceListFormView extends StatefulWidget {
  const _PriceListFormView({
    required this.title,
    required this.state,
    required this.fieldConfig,
    required this.onSave,
    required this.onBack,
    required this.onDelete,
    super.key,
  });

  final String title;
  final PriceListFormState state;
  final List<FieldConfigEntity> fieldConfig;
  final void Function(PriceListSaveRequested event) onSave;
  final VoidCallback onBack;
  final VoidCallback? onDelete;

  @override
  State<_PriceListFormView> createState() => _PriceListFormViewState();
}

class _PriceListFormViewState extends State<_PriceListFormView> {
  late final TextEditingController _description;
  late final TextEditingController _validity;
  late final TextEditingController _modality;

  /// 'S' (default) / 'N'.
  String _published = 'S';

  // R3: foco programático + marca inline SÓ do campo pendente.
  final _focus = {for (final name in _fieldNames) name: FocusNode()};
  final _keys = {
    for (final name in _fieldNames) name: GlobalKey<FormFieldState<String>>(),
  };

  /// Nomes do PAYLOAD (camelCase) na ordem da tela — casam com o fields[]
  /// do servidor (DTO Zod do módulo price-lists).
  static const _fieldNames = ['description', 'validity', 'modality'];

  PriceListEntity? get _editing => widget.state.editing;

  @override
  void initState() {
    super.initState();
    final editing = _editing;
    _description = TextEditingController(text: editing?.description ?? '');
    _validity =
        TextEditingController(text: isoDateToDisplay(editing?.validity));
    _modality = TextEditingController(text: editing?.modality ?? '');
    _published = editing?.published ?? 'S';
  }

  @override
  void dispose() {
    _description.dispose();
    _validity.dispose();
    _modality.dispose();
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
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
  // Validação (R3/R6): DTO Zod (description 1..45, modality 1 char,
  // validity yyyy-MM-dd) + catálogo do cliente.
  // ------------------------------------------------------------------

  String? _validateDescription(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'register.requiredField'
          .tr(args: [_label('description', 'forms.priceLists.description')]);
    }
    return _maskError('description', text);
  }

  String? _validateValidity(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return _requiredCfg('validity')
          ? 'register.requiredField'
              .tr(args: [_label('validity', 'forms.priceLists.validity')])
          : null;
    }
    return displayDateToIso(text) == null ? 'register.invalidDate'.tr() : null;
  }

  String? _validateModality(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return _requiredCfg('modality')
          ? 'register.requiredField'
              .tr(args: [_label('modality', 'forms.priceLists.modality')])
          : null;
    }
    return _maskError('modality', text);
  }

  /// Campos NA ORDEM da tela (R3); names = payload da API.
  List<PendencyField> get _pendencyFields => [
        _text('description', () => _validateDescription(_description.text)),
        _text('validity', () => _validateValidity(_validity.text)),
        _text('modality', () => _validateModality(_modality.text)),
        PendencyField(name: 'published', validate: () => null),
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
    widget.onSave(PriceListSaveRequested(
      editingId: _editing?.id,
      input: PriceListInput(
        description: _unmasked('description', _description),
        validity:    displayDateToIso(_validity.text),
        modality:    _optionalUnmasked('modality', _modality),
        published:   _published,
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

  @override
  Widget build(BuildContext context) {
    // Tabulação: Tab só nos campos editáveis na ordem declarada; o radio
    // fica fora da sequência (regra dos checkboxes).
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
            field(SetesTextField(
              label: _label('description', 'forms.priceLists.description'),
              controller: _description,
              focusNode: _focus['description'],
              fieldKey: _keys['description'],
              autofocus: true,
              textInputAction: TextInputAction.next,
              validator: _validateDescription,
              inputFormatters: _formatters(
                  'description', LengthLimitingTextInputFormatter(45)),
            )),
            const SizedBox(height: 16),
            field(SetesTextField(
              label: _label('validity', 'forms.priceLists.validity'),
              hint: 'register.dateHint'.tr(),
              controller: _validity,
              focusNode: _focus['validity'],
              fieldKey: _keys['validity'],
              textInputAction: TextInputAction.next,
              validator: _validateValidity,
            )),
            const SizedBox(height: 16),
            field(SetesTextField(
              label: _label('modality', 'forms.priceLists.modality'),
              hint: 'forms.priceLists.modalityHint'.tr(),
              controller: _modality,
              focusNode: _focus['modality'],
              fieldKey: _keys['modality'],
              textInputAction: TextInputAction.done,
              validator: _validateModality,
              inputFormatters: _formatters(
                  'modality', LengthLimitingTextInputFormatter(1)),
            )),
            const SizedBox(height: 16),
            SetesRadioGroup<String>(
              label: _label('published', 'forms.priceLists.published'),
              value: _published,
              options: [
                SetesRadioOption(value: 'S', label: 'register.yes'.tr()),
                SetesRadioOption(value: 'N', label: 'register.no'.tr()),
              ],
              onChanged: (v) => setState(() => _published = v ?? 'S'),
            ),
          ],
        ),
      ),
    );
  }
}
