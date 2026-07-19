import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_validators/setes_validators.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/feedback/feedback.dart';
import '../../../../shared/field_config/entity/field_config_entity.dart';
import '../../../../shared/field_config/field_config_loader.dart';
import '../../../../shared/register/register_search_page.dart';
import '../../data/datasource/payment_type_datasource.dart';
import '../../domain/entity/payment_type_entity.dart';
import '../bloc/payment_type_bloc.dart';

/// Tela de Formas de Pagamento — interface 'payment-types', grupo
/// Financeiro (workflow do Valdo, 2026-07-18): o CLIENTE inicia o cadastro.
///
/// Lista = formas VINCULADAS à institution. No form de inclusão, o campo
/// Descrição tem lupa que abre o CATÁLOGO central (existente = só vincula);
/// descrição digitada livre = a API cria no catálogo (ou reusa por
/// descrição — SnackBar informa) e vincula. Na edição, a descrição é
/// SOMENTE LEITURA (chave do reuso na linha compartilhada); o código NF-e
/// (combobox) e os atributos do vínculo são editáveis — o código atualiza
/// a linha central para todos os clientes. Excluir = desvincular.
class PaymentTypePage extends StatefulWidget {
  const PaymentTypePage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das duas telas.
  final String title;

  @override
  State<PaymentTypePage> createState() => _PaymentTypePageState();
}

class _PaymentTypePageState extends State<PaymentTypePage>
    with FieldConfigLoader {
  late final PaymentTypeBloc _bloc;
  late final PaymentTypeDatasource _datasource;

  /// Acesso ao estado do form artesanal: ancora o fields[] do servidor no
  /// campo (showServerFieldError — Framework de Mensagens, Onda B).
  final _formViewKey = GlobalKey<_PaymentTypeFormViewState>();

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<PaymentTypeBloc>()
      ..add(const PaymentTypeListRequested('', refresh: true));
    _datasource = Modular.get<PaymentTypeDatasource>();
    // Engine de campos configuráveis (decisão 7) — catálogo do seed 14.
    loadFieldConfig('payment-types');
  }

  Widget _buildSearch(PaymentTypeListState state) =>
      RegisterSearchPage<LinkedPaymentType>(
        title: 'register.listTitle'.tr(args: [widget.title]),
        // Engrenagem padrão da lista (Framework de Configurações, decisão 11)
        configModuleKey: 'payment-types',
        items: state.items,
        loading: state.loading,
        avatarBuilder: (p) => p.idNfce ?? '${p.id}',
        rowBuilder: (p) => [
          p.description ?? '',
          if (p.idNfce != null)
            '${'forms.paymentType.idNfce'.tr()}: ${NfceCode.displayOf(p.idNfce)}',
          p.attrs.enable
              ? 'forms.paymentType.enabledRow'.tr()
              : 'forms.paymentType.disabledRow'.tr(),
          if (p.attrs.appMobile) 'forms.paymentType.appMobile'.tr(),
        ],
        onFilterChanged: (filter) =>
            _bloc.add(PaymentTypeListRequested(filter)),
        onNew: () => _bloc.add(const PaymentTypeNewPressed()),
        onView: (p) => _bloc.add(PaymentTypeEditPressed(p)),
      );

  Widget _buildForm(PaymentTypeFormState state) => _PaymentTypeFormView(
        key: _formViewKey,
        title: widget.title,
        state: state,
        datasource: _datasource,
        fieldConfig: fieldConfig,
        onSave: (event) => _bloc.add(event),
        onBack: () => _bloc.add(const PaymentTypeBackToListPressed()),
        onDelete: state.editing == null
            ? null
            : () => _bloc.add(PaymentTypeDeleteRequested(state.editing!.id)),
      );

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<PaymentTypeBloc, PaymentTypeState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is PaymentTypeActionSuccess ||
            current is PaymentTypeActionFailure,
        // PONTE de feedback (Framework de Mensagens): a tela nunca chama
        // ScaffoldMessenger/AlertDialog — sucesso = SnackBar via ponte (R1);
        // falha = dialog, com fields[] do servidor ancorado no campo do
        // formulário quando ele está montado.
        listener: (context, state) {
          if (state is PaymentTypeActionSuccess) {
            showSuccessFeedback(context, state.messageKey);
            return;
          }
          final failure = (state as PaymentTypeActionFailure).failure;
          final form = _formViewKey.currentState;
          if (failure.fields.isNotEmpty && form != null) {
            form.showServerFieldError(failure);
          } else {
            showFailureFeedback(context, failure);
          }
        },
        buildWhen: (_, current) =>
            current is PaymentTypeListState || current is PaymentTypeFormState,
        builder: (context, state) => switch (state) {
          PaymentTypeFormState() => _buildForm(state),
          PaymentTypeListState() => _buildSearch(state),
          _ => _buildSearch(const PaymentTypeListState(loading: true)),
        },
      );
}

/// Form da forma de pagamento (SetesFormShell): descrição com lupa do
/// catálogo central + código NFC-e + toggles do vínculo.
///
/// Framework de Mensagens (Onda B): validação local com setes_validators e
/// UMA pendência por vez (R3 — dialog da ponte + foco no campo, padrão da
/// fábrica); captions/required do catálogo do cliente via [fieldConfig]
/// (engine da Fase 2, moduleKey 'payment-types').
class _PaymentTypeFormView extends StatefulWidget {
  const _PaymentTypeFormView({
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
  final PaymentTypeFormState state;
  final PaymentTypeDatasource datasource;

  /// Config resolvida do módulo (FieldConfigLoader da página).
  final List<FieldConfigEntity> fieldConfig;

  final void Function(PaymentTypeSaveRequested event) onSave;
  final VoidCallback onBack;
  final VoidCallback? onDelete;

  @override
  State<_PaymentTypeFormView> createState() => _PaymentTypeFormViewState();
}

class _PaymentTypeFormViewState extends State<_PaymentTypeFormView> {
  late final TextEditingController _description;
  late final TextEditingController _maxParcels;

  /// Foco programático (R3): após o OK do dialog de pendência, o foco
  /// volta para o campo pendente — mesmo contrato da fábrica.
  final _descriptionFocus = FocusNode();
  final _maxParcelsFocus = FocusNode();

  /// Forma escolhida no catálogo (lupa) — null = descrição digitada livre.
  int? _catalogId;

  /// Código NF-e escolhido na combobox ('' = sem código).
  String _idNfceCode = '';

  late bool _enable;
  late bool _appMobile;
  late bool _blockForCustomerBlocked;
  late bool _blockForCustomerNoLimit;
  late bool _tef;
  late String _usagePreference;
  int _planCreId = 0;
  String _planCreDescription = '';
  int _planDebId = 0;
  String _planDebDescription = '';

  LinkedPaymentType? get _editing => widget.state.editing;
  bool get _creating => _editing == null;

  @override
  void initState() {
    super.initState();
    final editing = _editing;
    final attrs = editing?.attrs ?? const PaymentTypeLinkAttrs();
    _description = TextEditingController(text: editing?.description ?? '');
    _maxParcels  = TextEditingController(text: '${attrs.maxParcels}');
    _idNfceCode  = editing?.idNfce ?? '';
    _enable      = attrs.enable;
    _appMobile   = attrs.appMobile;
    _blockForCustomerBlocked = attrs.blockForCustomerBlocked;
    _blockForCustomerNoLimit = attrs.blockForCustomerNoLimit;
    _tef             = attrs.tef;
    _usagePreference = attrs.usagePreference;
    _planCreId          = attrs.financialPlansIdCre;
    _planCreDescription = editing?.financialPlanCreDescription ?? '';
    _planDebId          = attrs.financialPlansIdDeb;
    _planDebDescription = editing?.financialPlanDebDescription ?? '';
  }

  @override
  void dispose() {
    _description.dispose();
    _maxParcels.dispose();
    _descriptionFocus.dispose();
    _maxParcelsFocus.dispose();
    super.dispose();
  }

  /// Config do catálogo do cliente para o campo (null = sem especialização).
  FieldConfigEntity? _configOf(String nameCamel) {
    for (final config in widget.fieldConfig) {
      if (config.fieldNameCamel == nameCamel) return config;
    }
    return null;
  }

  /// Caption do cliente quando existe; senão a chave i18n padrão do app
  /// (engine de campos configuráveis, decisão 7).
  String _label(String nameCamel, String i18nKey) =>
      _configOf(nameCamel)?.caption ?? i18nKey.tr();

  /// Lupa do catálogo central: escolher = SÓ VINCULAR (descrição/NF-e
  /// preenchidos e travados). Limpar volta ao modo "digitar livre".
  Future<void> _pickFromCatalog() async {
    final picked = await showSetesLookup<PaymentTypeCatalogItem>(
      context: context,
      title: 'forms.paymentType.catalog'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: widget.datasource.catalog,
      itemId: (p) => p.id,
      itemLabel: (p) => p.linked
          ? '${p.description ?? ''} (${'forms.paymentType.alreadyLinked'.tr()})'
          : p.description ?? '',
    );
    if (picked != null) {
      setState(() {
        _catalogId = picked.id;
        _description.text = picked.description ?? '';
        _idNfceCode = picked.idNfce ?? '';
      });
    }
  }

  /// Lookup do Plano de Contas ([kind] 'R' Resultado / 'C' Centro de
  /// Custo) — grava o id no estado, exibe caminho + descrição.
  Future<void> _pickFinancialPlan(String kind) async {
    final picked = await showSetesLookup<FinancialPlanLookupItem>(
      context: context,
      title: kind == 'R'
          ? 'forms.paymentType.planCre'.tr()
          : 'forms.paymentType.planDeb'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: (filter) => widget.datasource.financialPlans(filter, kind),
      itemId: (p) => p.id,
      itemLabel: (p) => p.display,
    );
    if (picked != null) {
      setState(() {
        if (kind == 'R') {
          _planCreId = picked.id;
          _planCreDescription = picked.display;
        } else {
          _planDebId = picked.id;
          _planDebDescription = picked.display;
        }
      });
    }
  }

  PaymentTypeLinkAttrs get _attrs => PaymentTypeLinkAttrs(
        enable:                  _enable,
        appMobile:               _appMobile,
        blockForCustomerBlocked: _blockForCustomerBlocked,
        blockForCustomerNoLimit: _blockForCustomerNoLimit,
        maxParcels:              int.tryParse(_maxParcels.text.trim()) ?? 1,
        tef:                     _tef,
        financialPlansIdCre:     _planCreId,
        financialPlansIdDeb:     _planDebId,
        usagePreference:         _usagePreference,
      );

  /// R3 — UMA pendência por vez (padrão da fábrica): valida os campos na
  /// ordem visual com setes_validators; a 1ª pendência vira dialog da ponte
  /// → OK → foco no campo; o salvar aborta e o próximo Salvar revalida.
  Future<void> _save() async {
    // Descrição: obrigatória na criação livre (baseline 'S' do catálogo —
    // seed 14); escolhida na lupa ou em edição o campo é readOnly.
    if (_creating && _catalogId == null) {
      final message = SetesValidators.required()(_description.text);
      if (message != null) {
        await showValidationFeedback(context, message.tr());
        if (!mounted) return;
        _descriptionFocus.requestFocus();
        return;
      }
    }
    // Máximo de parcelas: inteiro >= 1 (regra técnica da tela).
    final parcels = int.tryParse(_maxParcels.text.trim());
    if (parcels == null || parcels < 1) {
      await showValidationFeedback(
          context, 'forms.paymentType.maxParcelsInvalid'.tr());
      if (!mounted) return;
      _maxParcelsFocus.requestFocus();
      return;
    }
    widget.onSave(PaymentTypeSaveRequested(
      editingId:   _editing?.id,
      catalogId:   _catalogId,
      description: _description.text.trim(),
      idNfce:      _idNfceCode.isEmpty ? null : _idNfceCode,
      attrs:       _attrs,
    ));
  }

  /// Ancora o erro de campo do SERVIDOR (`fields[]` do envelope 400/409)
  /// no form artesanal: dialog com a message do 1º campo apontado → OK →
  /// foco nele quando é focável. A página chama no listener do bloc via
  /// GlobalKey (equivalente ao showServerFieldError da fábrica).
  Future<void> showServerFieldError(Failure failure) async {
    if (failure.fields.isEmpty) return showFailureFeedback(context, failure);

    final serverField = failure.fields.first;
    final focus = {
      'description': _descriptionFocus,
      'maxParcels': _maxParcelsFocus,
    }[serverField.field];
    if (focus == null) return showFailureFeedback(context, failure);

    await showValidationFeedback(context, serverField.message.tr());
    if (!mounted) return;
    focus.requestFocus();
  }

  /// Desvincular confirmado via decisão TIPADA da ponte (R4): Sim =
  /// desvincular; Cancelar (ou fechar) = nada — sem ação alternativa,
  /// então sem botão Não.
  Future<void> _confirmDelete() async {
    final decision = await askDecision(
      context,
      message: 'forms.paymentType.confirmUnlink'.tr(),
      yesLabel: 'register.delete'.tr(),
    );
    if (decision == SetesDecision.yes) widget.onDelete?.call();
  }

  /// Código NF-e: combobox da LISTA FISCAL FIXA (grava só os 2 dígitos) —
  /// disponível na criação livre E na edição (o PUT atualiza a linha
  /// central compartilhada); travado só quando a forma veio da lupa do
  /// catálogo (aí vira campo somente leitura com o "código - descrição").
  Widget _buildIdNfce(bool catalogLocked) {
    if (catalogLocked) {
      return SetesTextField(
        key: ValueKey('nfce-locked-$_idNfceCode'),
        label: _label('idNfce', 'forms.paymentType.idNfce'),
        controller:
            TextEditingController(text: NfceCode.displayOf(_idNfceCode)),
        readOnly: true,
      );
    }
    final none = NfceCode('', 'forms.paymentType.idNfceNone'.tr());
    final items = [none, ...NfceCode.all];
    return SetesDropdown<NfceCode>(
      label: _label('idNfce', 'forms.paymentType.idNfce'),
      value: items.firstWhere((c) => c.code == _idNfceCode,
          orElse: () => items.first),
      items: items,
      itemLabel: (c) => c.code.isEmpty ? c.label : c.display,
      onChanged: (picked) =>
          setState(() => _idNfceCode = picked?.code ?? ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Descrição/NF-e travados na edição (catálogo compartilhado) e também
    // quando uma forma do catálogo foi escolhida na lupa.
    final catalogLocked = !_creating || _catalogId != null;
    return SetesFormShell(
      title: widget.title,
      saving: widget.state.saving,
      onBack: widget.onBack,
      onSave: _save,
      onDelete: widget.onDelete != null ? _confirmDelete : null,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SetesTextField(
            label: _label('description', 'forms.paymentType.description'),
            hint: _creating ? 'forms.paymentType.descriptionHint'.tr() : null,
            controller: _description,
            focusNode: _descriptionFocus,
            readOnly: catalogLocked,
            autofocus: _creating,
            suffixIcon: _creating ? Icons.search : null,
            onSuffixPressed: _creating
                ? (_catalogId == null
                    ? _pickFromCatalog
                    : () => setState(() {
                          _catalogId = null;
                          _description.clear();
                          _idNfceCode = '';
                        }))
                : null,
          ),
          const SizedBox(height: 16),
          _buildIdNfce(_catalogId != null),
          const SizedBox(height: 16),
          SetesTextField(
            label: _label('maxParcels', 'forms.paymentType.maxParcels'),
            hint: 'forms.paymentType.maxParcelsHint'.tr(),
            controller: _maxParcels,
            focusNode: _maxParcelsFocus,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          SetesRadioGroup<String>(
            label: _label('usagePreference', 'forms.paymentType.usagePreference'),
            helperText: 'forms.paymentType.usagePreferenceHelper'.tr(),
            value: _usagePreference,
            options: [
              SetesRadioOption(
                  value: 'C', label: 'forms.paymentType.usageCashier'.tr()),
              SetesRadioOption(
                  value: 'B', label: 'forms.paymentType.usageBank'.tr()),
              SetesRadioOption(
                  value: 'A', label: 'forms.paymentType.usageBoth'.tr()),
            ],
            onChanged: (value) =>
                setState(() => _usagePreference = value ?? 'A'),
          ),
          const SizedBox(height: 16),
          SetesLookupField(
            label: _label('tbFinancialPlansIdCre', 'forms.paymentType.planCre'),
            display: _planCreDescription,
            onSearch: () => _pickFinancialPlan('R'),
            onClear: () => setState(() {
              _planCreId = 0;
              _planCreDescription = '';
            }),
          ),
          const SizedBox(height: 16),
          SetesLookupField(
            label: _label('tbFinancialPlansIdDeb', 'forms.paymentType.planDeb'),
            display: _planDebDescription,
            onSearch: () => _pickFinancialPlan('C'),
            onClear: () => setState(() {
              _planDebId = 0;
              _planDebDescription = '';
            }),
          ),
          const SizedBox(height: 8),
          ExcludeFocusTraversal(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SetesCheckbox(
                  label: _label('enable', 'forms.paymentType.enable'),
                  value: _enable,
                  onChanged: (checked) =>
                      setState(() => _enable = checked ?? true),
                ),
                SetesCheckbox(
                  label: _label('appMobile', 'forms.paymentType.appMobile'),
                  value: _appMobile,
                  onChanged: (checked) =>
                      setState(() => _appMobile = checked ?? false),
                ),
                SetesCheckbox(
                  label: _label('tef', 'forms.paymentType.tef'),
                  value: _tef,
                  onChanged: (checked) =>
                      setState(() => _tef = checked ?? false),
                ),
                SetesCheckbox(
                  label: _label('blockForCustomerBlocked',
                      'forms.paymentType.blockForCustomerBlocked'),
                  value: _blockForCustomerBlocked,
                  onChanged: (checked) => setState(
                      () => _blockForCustomerBlocked = checked ?? false),
                ),
                SetesCheckbox(
                  label: _label('blockForCustomerNoLimit',
                      'forms.paymentType.blockForCustomerNoLimit'),
                  value: _blockForCustomerNoLimit,
                  onChanged: (checked) => setState(
                      () => _blockForCustomerNoLimit = checked ?? false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
