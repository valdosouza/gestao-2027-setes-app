import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

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

class _PaymentTypePageState extends State<PaymentTypePage> {
  late final PaymentTypeBloc _bloc;
  late final PaymentTypeDatasource _datasource;

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<PaymentTypeBloc>()
      ..add(const PaymentTypeListRequested('', refresh: true));
    _datasource = Modular.get<PaymentTypeDatasource>();
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
        key: ValueKey(state.editing?.id ?? 'payment-type-new'),
        title: widget.title,
        state: state,
        datasource: _datasource,
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
        listener: (context, state) {
          final message = state is PaymentTypeActionSuccess
              ? state.messageKey.tr()
              : (state as PaymentTypeActionFailure).message;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: SetesText(message)));
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
class _PaymentTypeFormView extends StatefulWidget {
  const _PaymentTypeFormView({
    required this.title,
    required this.state,
    required this.datasource,
    required this.onSave,
    required this.onBack,
    required this.onDelete,
    super.key,
  });

  final String title;
  final PaymentTypeFormState state;
  final PaymentTypeDatasource datasource;
  final void Function(PaymentTypeSaveRequested event) onSave;
  final VoidCallback onBack;
  final VoidCallback? onDelete;

  @override
  State<_PaymentTypeFormView> createState() => _PaymentTypeFormViewState();
}

class _PaymentTypeFormViewState extends State<_PaymentTypeFormView> {
  late final TextEditingController _description;
  late final TextEditingController _maxParcels;

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
    super.dispose();
  }

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

  void _save() {
    if (_creating &&
        _catalogId == null &&
        _description.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: SetesText('register.requiredField'
              .tr(args: ['forms.paymentType.description'.tr()]))));
      return;
    }
    final parcels = int.tryParse(_maxParcels.text.trim());
    if (parcels == null || parcels < 1) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: SetesText('forms.paymentType.maxParcelsInvalid'.tr())));
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

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: SetesText('forms.paymentType.confirmUnlink'.tr()),
        actions: [
          SetesButton(
            label: 'register.cancel'.tr(),
            kind: SetesButtonKind.text,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          SetesButton(
            label: 'register.delete'.tr(),
            kind: SetesButtonKind.text,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onDelete?.call();
  }

  /// Código NF-e: combobox da LISTA FISCAL FIXA (grava só os 2 dígitos) —
  /// disponível na criação livre E na edição (o PUT atualiza a linha
  /// central compartilhada); travado só quando a forma veio da lupa do
  /// catálogo (aí vira campo somente leitura com o "código - descrição").
  Widget _buildIdNfce(bool catalogLocked) {
    if (catalogLocked) {
      return SetesTextField(
        key: ValueKey('nfce-locked-$_idNfceCode'),
        label: 'forms.paymentType.idNfce'.tr(),
        controller:
            TextEditingController(text: NfceCode.displayOf(_idNfceCode)),
        readOnly: true,
      );
    }
    final none = NfceCode('', 'forms.paymentType.idNfceNone'.tr());
    final items = [none, ...NfceCode.all];
    return SetesDropdown<NfceCode>(
      label: 'forms.paymentType.idNfce'.tr(),
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
            label: 'forms.paymentType.description'.tr(),
            hint: _creating ? 'forms.paymentType.descriptionHint'.tr() : null,
            controller: _description,
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
            label: 'forms.paymentType.maxParcels'.tr(),
            hint: 'forms.paymentType.maxParcelsHint'.tr(),
            controller: _maxParcels,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          SetesRadioGroup<String>(
            label: 'forms.paymentType.usagePreference'.tr(),
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
            label: 'forms.paymentType.planCre'.tr(),
            display: _planCreDescription,
            onSearch: () => _pickFinancialPlan('R'),
            onClear: () => setState(() {
              _planCreId = 0;
              _planCreDescription = '';
            }),
          ),
          const SizedBox(height: 16),
          SetesLookupField(
            label: 'forms.paymentType.planDeb'.tr(),
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
                  label: 'forms.paymentType.enable'.tr(),
                  value: _enable,
                  onChanged: (checked) =>
                      setState(() => _enable = checked ?? true),
                ),
                SetesCheckbox(
                  label: 'forms.paymentType.appMobile'.tr(),
                  value: _appMobile,
                  onChanged: (checked) =>
                      setState(() => _appMobile = checked ?? false),
                ),
                SetesCheckbox(
                  label: 'forms.paymentType.tef'.tr(),
                  value: _tef,
                  onChanged: (checked) =>
                      setState(() => _tef = checked ?? false),
                ),
                SetesCheckbox(
                  label: 'forms.paymentType.blockForCustomerBlocked'.tr(),
                  value: _blockForCustomerBlocked,
                  onChanged: (checked) => setState(
                      () => _blockForCustomerBlocked = checked ?? false),
                ),
                SetesCheckbox(
                  label: 'forms.paymentType.blockForCustomerNoLimit'.tr(),
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
