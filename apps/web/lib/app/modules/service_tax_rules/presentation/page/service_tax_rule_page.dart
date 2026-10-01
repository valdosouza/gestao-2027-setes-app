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
import '../../../../shared/lookup/datasource/city_lookup_datasource.dart';
import '../../../../shared/lookup/datasource/state_lookup_datasource.dart';
import '../../../../shared/lookup/entity/city_lookup_entity.dart';
import '../../../../shared/lookup/entity/state_lookup_entity.dart';
import '../../../../shared/register/register_search_page.dart';
import '../../data/datasource/service_tax_rule_lookup_datasource.dart';
import '../../domain/entity/service_tax_rule_entity.dart';
import '../bloc/service_tax_rule_bloc.dart';

/// Tela de Regras de Tributação de Serviço — interface 'service-tax-rules'
/// (prompt_regra_tributacao_servico.md, D1–D14).
///
/// Lista = "item - descrição" + "cidade/UF" + código nacional efetivo +
/// alíquota + situação. Form em coluna única: Estado (lookup shared) →
/// Cidade de Incidência (lookup DEPENDENTE do estado — campo-lookup-fk.md
/// item 5) → Item da Lista de Serviços (lookup do próprio módulo) → Código
/// de Tributação Nacional (lookup DEPENDENTE do item — Onda 3 NFS-e: 1
/// desdobro = derivado e somente leitura; N = escolha obrigatória) →
/// Alíquota do ISS → Código de Tributação Municipal → Ativo.
///
/// Feedback 100% via PONTE (Framework de Mensagens): validação
/// uma-pendência-por-vez (R3), fields[] do servidor ancorado no campo,
/// exclusão via decisão tipada (R4) — o 409 SERVICE_TAX_RULE_IN_USE do
/// DELETE chega pela mesma ponte. Catálogo de campos (seed sql/44)
/// aplicado pelo FieldConfigLoader (caption/required/mask do cliente).
class ServiceTaxRulePage extends StatefulWidget {
  const ServiceTaxRulePage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das duas telas.
  final String title;

  @override
  State<ServiceTaxRulePage> createState() => _ServiceTaxRulePageState();
}

class _ServiceTaxRulePageState extends State<ServiceTaxRulePage>
    with FieldConfigLoader {
  late final ServiceTaxRuleBloc _bloc;
  late final ServiceTaxRuleLookupDatasource _lookup;
  late final StateLookupDatasource _stateLookup;
  late final CityLookupDatasource _cityLookup;

  /// Acesso ao estado do form híbrido: ancora o fields[] do servidor no
  /// campo. O form só está montado no modo formulário.
  final _formViewKey = GlobalKey<_ServiceTaxRuleFormViewState>();

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<ServiceTaxRuleBloc>()
      ..add(const ServiceTaxRuleListRequested(''));
    _lookup      = Modular.get<ServiceTaxRuleLookupDatasource>();
    _stateLookup = Modular.get<StateLookupDatasource>();
    _cityLookup  = Modular.get<CityLookupDatasource>();
    loadFieldConfig('service-tax-rules'); // engine de campos configuráveis
  }

  Widget _buildSearch(ServiceTaxRuleListState state) =>
      RegisterSearchPage<ServiceTaxRuleEntity>(
        title: 'register.listTitle'.tr(args: [widget.title]),
        configModuleKey: 'service-tax-rules',
        items: state.items,
        loading: state.loading,
        avatarBuilder: (r) => '${r.id}',
        rowBuilder: (r) => [
          r.serviceListDisplay,
          r.cityDisplay,
          if (r.effectiveNationalCode != null)
            'forms.serviceTaxRules.nationalCodeRow'
                .tr(args: [r.effectiveNationalCode!]),
          'forms.serviceTaxRules.aliqRow'.tr(args: [_formatDecimal(r.aliq)]),
          r.active == 'S'
              ? 'forms.serviceTaxRules.activeRow'.tr()
              : 'forms.serviceTaxRules.inactiveRow'.tr(),
        ],
        page: state.page,
        pageSize: state.pageSize,
        total: state.total,
        onPageChanged: (page) =>
            _bloc.add(ServiceTaxRuleListRequested(state.filter, page: page)),
        onPageSizeChanged: (size) => _bloc
            .add(ServiceTaxRuleListRequested(state.filter, pageSize: size)),
        filter: state.filter,
        onFilterChanged: (filter) =>
            _bloc.add(ServiceTaxRuleListRequested(filter)),
        onNew: () => _bloc.add(const ServiceTaxRuleNewPressed()),
        onView: (r) => _bloc.add(ServiceTaxRuleEditPressed(r.id)),
      );

  Widget _buildForm(ServiceTaxRuleFormState state) => _ServiceTaxRuleFormView(
        key: _formViewKey,
        title: widget.title,
        state: state,
        lookup: _lookup,
        stateLookup: _stateLookup,
        cityLookup: _cityLookup,
        fieldConfig: fieldConfig,
        onSave: (event) => _bloc.add(event),
        onBack: () => _bloc.add(const ServiceTaxRuleBackToListPressed()),
        onDelete: state.editing == null
            ? null
            : () =>
                _bloc.add(ServiceTaxRuleDeleteRequested(state.editing!.id)),
      );

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<ServiceTaxRuleBloc, ServiceTaxRuleState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is ServiceTaxRuleActionSuccess ||
            current is ServiceTaxRuleActionFailure,
        listener: (context, state) {
          if (state is ServiceTaxRuleActionSuccess) {
            showSuccessFeedback(context, state.messageKey);
            return;
          }
          final failure = (state as ServiceTaxRuleActionFailure).failure;
          final form = _formViewKey.currentState;
          if (failure.fields.isNotEmpty && form != null) {
            form.showServerFieldError(failure);
          } else {
            showFailureFeedback(context, failure);
          }
        },
        buildWhen: (_, current) =>
            current is ServiceTaxRuleListState ||
            current is ServiceTaxRuleFormState,
        builder: (context, state) => switch (state) {
          ServiceTaxRuleFormState() => _buildForm(state),
          ServiceTaxRuleListState() => _buildSearch(state),
          _ => _buildSearch(const ServiceTaxRuleListState(loading: true)),
        },
      );
}

/// Valor decimal digitado no padrão pt-BR ("2,50") → double (null quando
/// vazio ou inválido).
double? _parseDecimal(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  return double.tryParse(t.replaceAll('.', '').replaceAll(',', '.'));
}

/// double → texto pt-BR com 2 casas.
String _formatDecimal(double value) =>
    value.toStringAsFixed(2).replaceAll('.', ',');

/// Form da regra (SetesFormShell, coluna única).
class _ServiceTaxRuleFormView extends StatefulWidget {
  const _ServiceTaxRuleFormView({
    required this.title,
    required this.state,
    required this.lookup,
    required this.stateLookup,
    required this.cityLookup,
    required this.fieldConfig,
    required this.onSave,
    required this.onBack,
    required this.onDelete,
    super.key,
  });

  final String title;
  final ServiceTaxRuleFormState state;
  final ServiceTaxRuleLookupDatasource lookup;
  final StateLookupDatasource stateLookup;
  final CityLookupDatasource cityLookup;

  /// Catálogo resolvido da interface (tb_interface_has_field × cliente).
  final List<FieldConfigEntity> fieldConfig;
  final void Function(ServiceTaxRuleSaveRequested event) onSave;
  final VoidCallback onBack;
  final VoidCallback? onDelete;

  @override
  State<_ServiceTaxRuleFormView> createState() =>
      _ServiceTaxRuleFormViewState();
}

class _ServiceTaxRuleFormViewState extends State<_ServiceTaxRuleFormView> {
  late final TextEditingController _aliq;
  late final TextEditingController _municipalCode;

  // R3: foco programático + marca inline SÓ do campo pendente.
  final _focus = {for (final name in _fieldNames) name: FocusNode()};
  final _keys = {
    for (final name in _fieldNames) name: GlobalKey<FormFieldState<String>>(),
  };

  /// Nomes do PAYLOAD (camelCase) dos campos de texto — casam com o
  /// fields[] do servidor (DTO Zod do módulo service-tax-rules).
  static const _fieldNames = ['aliq', 'municipalCode'];

  /// Estado (UF) — só apoio do lookup dependente de cidade; NÃO viaja no
  /// payload. Na edição a API devolve apenas a sigla: o id é resolvido
  /// pelo lookup de estados na primeira abertura da lista de cidades.
  int? _stateId;
  String _stateAbbreviation = '';
  String _stateDisplay = '';

  /// Cidade de incidência — id salvo, nome exibido.
  int? _cityId;
  String _cityDisplay = '';

  /// Item da Lista de Serviços — id textual ('1.02') salvo, "id - descrição"
  /// exibido.
  String? _serviceListId;
  String _serviceListDisplay = '';

  /// Código de tributação nacional — lookup DEPENDENTE do item (Onda 3):
  /// [_nationalCodes] são os desdobros do item (null = ainda não buscados);
  /// [_nationalCode] é o código efetivo na tela; [_nationalCodeDerived] =
  /// o item tem UM desdobro (somente leitura, viaja null no payload);
  /// [_nationalCodeOptions] = quantos desdobros (>1 exige escolha).
  List<NationalCodeLookup>? _nationalCodes;
  String? _nationalCode;
  bool _nationalCodeDerived = false;
  int _nationalCodeOptions = 0;
  bool _nationalCodeLoading = false;

  /// Exibição do código derivado (campo somente leitura).
  final _nationalCodeText = TextEditingController();

  String _active = 'S';

  ServiceTaxRuleEntity? get _editing => widget.state.editing;

  @override
  void initState() {
    super.initState();
    final editing = _editing;
    _stateAbbreviation  = editing?.stateAbbreviation ?? '';
    _stateDisplay       = _stateAbbreviation;
    _cityId             = editing?.cityId;
    _cityDisplay        = editing?.cityName ?? '';
    _serviceListId      = editing?.serviceListId;
    _serviceListDisplay = editing?.serviceListDisplay ?? '';
    _active             = editing?.active ?? 'S';
    _aliq = TextEditingController(
        text: editing == null ? '' : _formatDecimal(editing.aliq));
    _municipalCode =
        TextEditingController(text: editing?.municipalCode ?? '');
    if (editing != null) {
      _nationalCode        = editing.nationalCode ?? editing.effectiveNationalCode;
      _nationalCodeDerived = editing.nationalCodeDerived;
      _nationalCodeOptions = editing.nationalCodeOptions;
      _nationalCodeText.text = _nationalCodeDisplay;
      // Descrição do desdobro vem do catálogo — busca em segundo plano
      // preservando a escolha gravada.
      _loadNationalCodes(editing.serviceListId, keepChoice: true);
    }
  }

  @override
  void dispose() {
    _aliq.dispose();
    _municipalCode.dispose();
    _nationalCodeText.dispose();
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Lookups (skill campo-lookup-fk.md): usuário nunca digita id.
  // ------------------------------------------------------------------

  String _stateLabel(StateLookup s) =>
      '${s.abbreviation ?? ''} · ${s.name ?? ''}';

  Future<void> _pickState() async {
    final picked = await showSetesLookup<StateLookup>(
      context: context,
      title: 'lookup.states'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: widget.stateLookup.list,
      itemId: (s) => s.id,
      itemLabel: _stateLabel,
    );
    if (picked != null) {
      setState(() {
        _stateId = picked.id;
        _stateAbbreviation = picked.abbreviation ?? '';
        _stateDisplay = _stateLabel(picked);
        // UF trocada: a cidade anterior deixa de valer (lookup dependente).
        _cityId = null;
        _cityDisplay = '';
      });
    }
  }

  /// Na edição a API só devolve a sigla da UF — resolve o id pela lista de
  /// estados (filtro pela sigla) antes de abrir o lookup de cidades.
  Future<int?> _resolveStateId() async {
    if (_stateId != null) return _stateId;
    if (_stateAbbreviation.isEmpty) return null;
    final states = await widget.stateLookup.list(_stateAbbreviation);
    for (final s in states) {
      if ((s.abbreviation ?? '').toUpperCase() ==
          _stateAbbreviation.toUpperCase()) {
        _stateId = s.id;
        if (mounted) setState(() => _stateDisplay = _stateLabel(s));
        return s.id;
      }
    }
    return null;
  }

  Future<void> _pickCity() async {
    // Lookup dependente (campo-lookup-fk.md, item 5): exige a UF primeiro —
    // pendência corrigível → dialog de validação da ponte.
    final stateId = await _resolveStateId();
    if (!mounted) return;
    if (stateId == null) {
      await showValidationFeedback(
          context, 'forms.serviceTaxRules.stateFirst'.tr());
      return;
    }
    final picked = await showSetesLookup<CityLookup>(
      context: context,
      title: 'lookup.cities'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: (filter) => widget.cityLookup.list(filter, stateId: stateId),
      itemId: (c) => c.id,
      itemLabel: (c) => c.name ?? '',
    );
    if (picked != null) {
      setState(() {
        _cityId = picked.id;
        _cityDisplay = picked.name ?? '';
      });
    }
  }

  Future<void> _pickServiceList() async {
    final picked = await showSetesLookup<ServiceListLookup>(
      context: context,
      title: 'forms.serviceTaxRules.serviceListLookupTitle'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: widget.lookup.serviceList,
      // id do item é textual ('1.02'): o avatar mostra o grupo, o rótulo
      // traz "id - descrição" completo.
      itemId: (s) => s.group,
      itemLabel: (s) => s.display,
    );
    if (picked != null) {
      setState(() {
        _serviceListId = picked.id;
        _serviceListDisplay = picked.display;
        // Item trocado: os desdobros anteriores deixam de valer.
        _nationalCodes = null;
        _nationalCode = null;
        _nationalCodeDerived = false;
        _nationalCodeOptions = 0;
        _nationalCodeText.clear();
      });
      await _loadNationalCodes(picked.id, keepChoice: false);
    }
  }

  // ------------------------------------------------------------------
  // Código de tributação nacional (lookup dependente do item — Onda 3).
  // ------------------------------------------------------------------

  /// "010201 - Descrição" quando o desdobro está carregado; senão só o código.
  String get _nationalCodeDisplay {
    final code = _nationalCode;
    if (code == null) return '';
    for (final o in _nationalCodes ?? const <NationalCodeLookup>[]) {
      if (o.id == code) return o.display;
    }
    return code;
  }

  /// Busca os desdobros do item: 1 → preenche sozinho (derivado); N →
  /// exige a escolha ([keepChoice] preserva a gravada se ainda existir);
  /// 0 → item sem código nacional.
  Future<void> _loadNationalCodes(String serviceListId,
      {required bool keepChoice}) async {
    setState(() => _nationalCodeLoading = true);
    try {
      final options = await widget.lookup.nationalCodes(serviceListId);
      if (!mounted || _serviceListId != serviceListId) return;
      setState(() {
        _nationalCodes = options;
        _nationalCodeOptions = options.length;
        if (options.length == 1) {
          _nationalCode = options.first.id;
          _nationalCodeDerived = true;
        } else {
          _nationalCodeDerived = false;
          final keep = keepChoice &&
              options.any((o) => o.id == _nationalCode);
          if (!keep) _nationalCode = null;
        }
        _nationalCodeText.text = _nationalCodeDisplay;
      });
    } on Failure catch (failure) {
      if (mounted) await showFailureFeedback(context, failure);
    } finally {
      if (mounted) setState(() => _nationalCodeLoading = false);
    }
  }

  Future<void> _pickNationalCode() async {
    // Lookup dependente (campo-lookup-fk.md, item 5): exige o item primeiro.
    final serviceListId = _serviceListId;
    if (serviceListId == null) {
      await showValidationFeedback(
          context, 'forms.serviceTaxRules.nationalCodeChooseServiceFirst'.tr());
      return;
    }
    if (_nationalCodes == null) {
      await _loadNationalCodes(serviceListId, keepChoice: true);
      if (!mounted || _nationalCodeDerived) return;
    }
    final options = _nationalCodes ?? const <NationalCodeLookup>[];
    final picked = await showSetesLookup<NationalCodeLookup>(
      context: context,
      title: 'forms.serviceTaxRules.nationalCodeLookupTitle'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      // Lista já carregada: filtro LOCAL por código/descrição.
      onSearch: (filter) async {
        final f = filter.trim().toLowerCase();
        return f.isEmpty
            ? options
            : options
                .where((o) => o.display.toLowerCase().contains(f))
                .toList();
      },
      itemId: (o) => o.sequence,
      itemLabel: (o) => o.display,
    );
    if (picked != null) {
      setState(() {
        _nationalCode = picked.id;
        _nationalCodeText.text = _nationalCodeDisplay;
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
  // Validação (R3/R6): catálogo (seed sql/44: tb_city_id S,
  // tb_service_list_id S, aliq S, municipal_code N, active N) + DTO Zod
  // (aliq 0–100, municipalCode ≤ 20) como fontes.
  // ------------------------------------------------------------------

  /// Alíquota: obrigatória, decimal pt-BR entre 0 e 100.
  String? _validateAliq(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'register.requiredField'
          .tr(args: [_label('aliq', 'forms.serviceTaxRules.aliq')]);
    }
    final parsed = _parseDecimal(text);
    if (parsed == null || parsed < 0 || parsed > 100) {
      return 'forms.serviceTaxRules.aliqInvalid'.tr();
    }
    return null;
  }

  /// Código municipal: opcional (cliente pode apertar/mascarar), ≤ 20.
  String? _validateMunicipalCode(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return _requiredCfg('municipal_code')
          ? 'register.requiredField'.tr(args: [
              _label('municipal_code', 'forms.serviceTaxRules.municipalCode')
            ])
          : null;
    }
    if (text.length > 20) {
      return 'forms.serviceTaxRules.municipalCodeTooLong'.tr();
    }
    return _maskError('municipal_code', text);
  }

  /// Campos NA ORDEM da tela (R3). Os names casam com o payload da API —
  /// é por eles que o fields[] do servidor ancora no campo.
  List<PendencyField> get _pendencyFields => [
        PendencyField(
          name: 'cityId',
          validate: () => _cityId == null
              ? 'register.requiredField'.tr(
                  args: [_label('tb_city_id', 'forms.serviceTaxRules.city')])
              : null,
        ),
        PendencyField(
          name: 'serviceListId',
          validate: () => _serviceListId == null
              ? 'register.requiredField'.tr(args: [
                  _label('tb_service_list_id',
                      'forms.serviceTaxRules.serviceList')
                ])
              : null,
        ),
        // Obrigatório SÓ quando o item tem mais de um desdobro (validação
        // local espelhando a regra da API); derivado nunca pende.
        PendencyField(
          name: 'nationalCode',
          validate: () => _nationalCodeOptions > 1 &&
                  !_nationalCodeDerived &&
                  _nationalCode == null
              ? 'forms.serviceTaxRules.nationalCodeRequired'.tr()
              : null,
        ),
        _text('aliq', () => _validateAliq(_aliq.text)),
        _text('municipalCode',
            () => _validateMunicipalCode(_municipalCode.text)),
        PendencyField(name: 'active', validate: () => null),
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
    widget.onSave(ServiceTaxRuleSaveRequested(
      editingId: _editing?.id,
      input: ServiceTaxRuleInput(
        cityId:        _cityId!,
        serviceListId: _serviceListId!,
        aliq:          _parseDecimal(_aliq.text)!,
        municipalCode: _optionalUnmasked('municipal_code', _municipalCode),
        // Derivado viaja null — a API deriva do item; só a ESCOLHA é gravada.
        nationalCode:  _nationalCodeDerived ? null : _nationalCode,
        active:        _active,
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

  /// Campo "Código de Tributação Nacional": derivado → somente leitura com
  /// o texto "derivado do item"; N desdobros → lookup com escolha
  /// obrigatória; 0 → aviso de item sem código nacional.
  List<Widget> _nationalCodeField(BuildContext context) {
    final label = 'forms.serviceTaxRules.nationalCode'.tr();
    final helperStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    if (_nationalCodeDerived) {
      return [
        SetesTextField(
          label: label,
          controller: _nationalCodeText,
          readOnly: true,
        ),
        const SizedBox(height: 4),
        SetesText('forms.serviceTaxRules.nationalCodeDerived'.tr(),
            style: helperStyle),
      ];
    }
    final loaded = _nationalCodes != null && !_nationalCodeLoading;
    return [
      SetesLookupField(
        label: label,
        display: _nationalCodeDisplay,
        onSearch: _pickNationalCode,
        onClear: _nationalCode == null
            ? null
            : () => setState(() {
                  _nationalCode = null;
                  _nationalCodeText.clear();
                }),
      ),
      if (loaded && _nationalCodeOptions == 0 && _serviceListId != null) ...[
        const SizedBox(height: 4),
        SetesText('forms.serviceTaxRules.nationalCodeNone'.tr(),
            style: helperStyle),
      ] else if (loaded && _nationalCodeOptions > 1) ...[
        const SizedBox(height: 4),
        SetesText(
            'forms.serviceTaxRules.nationalCodeChoose'
                .tr(args: ['$_nationalCodeOptions']),
            style: helperStyle),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Tabulação: Tab só nos campos editáveis na ordem declarada; lookups e
    // radio ficam fora da sequência.
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
              label: 'forms.serviceTaxRules.state'.tr(),
              display: _stateDisplay,
              onSearch: _pickState,
            ),
            const SizedBox(height: 16),
            SetesLookupField(
              label: _label('tb_city_id', 'forms.serviceTaxRules.city'),
              display: _cityDisplay,
              onSearch: _pickCity,
            ),
            const SizedBox(height: 16),
            SetesLookupField(
              label: _label(
                  'tb_service_list_id', 'forms.serviceTaxRules.serviceList'),
              display: _serviceListDisplay,
              onSearch: _pickServiceList,
            ),
            const SizedBox(height: 16),
            ..._nationalCodeField(context),
            const SizedBox(height: 16),
            field(SetesTextField(
              label: _label('aliq', 'forms.serviceTaxRules.aliq'),
              controller: _aliq,
              focusNode: _focus['aliq'],
              fieldKey: _keys['aliq'],
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              validator: _validateAliq,
            )),
            const SizedBox(height: 16),
            field(SetesTextField(
              label: _label(
                  'municipal_code', 'forms.serviceTaxRules.municipalCode'),
              controller: _municipalCode,
              focusNode: _focus['municipalCode'],
              fieldKey: _keys['municipalCode'],
              textInputAction: TextInputAction.done,
              validator: _validateMunicipalCode,
              inputFormatters: _formatters(
                  'municipal_code', LengthLimitingTextInputFormatter(20)),
            )),
            const SizedBox(height: 16),
            SetesRadioGroup<String>(
              label: _label('active', 'forms.serviceTaxRules.active'),
              value: _active,
              options: [
                SetesRadioOption(value: 'S', label: 'register.yes'.tr()),
                SetesRadioOption(value: 'N', label: 'register.no'.tr()),
              ],
              onChanged: (v) => setState(() => _active = v ?? 'S'),
            ),
          ],
        ),
      ),
    );
  }
}
