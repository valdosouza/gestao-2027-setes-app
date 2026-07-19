import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/entity/widgets/entity_date.dart';
import '../../../../shared/feedback/feedback.dart';
import '../../../../shared/feedback/form_pendency.dart';
import '../../../../shared/field_config/entity/field_config_entity.dart';
import '../../../../shared/field_config/field_config_loader.dart';
import '../../../../shared/field_config/field_config_of.dart';
import '../../../../shared/format/money.dart';
import '../../../../shared/register/register_search_page.dart';
import '../../data/datasource/contract_datasource.dart';
import '../../domain/entity/contract_entity.dart';
import '../bloc/contract_bloc.dart';

/// Tela de Contratos de serviço — interface 'contracts', grupo Cadastros
/// (Módulo Software House, prompt fechado 2026-07-18).
///
/// Lista = contratos da institution com nome do cliente, vigência,
/// mensalidade (SUM dos itens — derivada) e situação. Form = cliente
/// (lookup /api/customers), datas, dia de vencimento INFORMATIVO (DP1) e
/// os ITENS do contrato (D9/DP3): produto (lookup /api/contracts/products)
/// + valor mensal, com total exibido e atualizado localmente.
///
/// Feedback 100% via PONTE (Framework de Mensagens, Onda B): validação
/// uma-pendência-por-vez (R3), fields[] do servidor ancorado no campo,
/// exclusão via decisão tipada (R4). Catálogo de campos (seed sql/16)
/// aplicado pelo FieldConfigLoader (caption/required do cliente).
class ContractPage extends StatefulWidget {
  const ContractPage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das duas telas.
  final String title;

  @override
  State<ContractPage> createState() => _ContractPageState();
}

class _ContractPageState extends State<ContractPage> with FieldConfigLoader {
  late final ContractBloc _bloc;
  late final ContractDatasource _datasource;

  /// Acesso ao estado do form híbrido: ancora o fields[] do servidor no
  /// campo (equivalente local do showServerFieldError da fábrica). O form
  /// só está montado no modo formulário — na lista o currentState é null.
  final _formViewKey = GlobalKey<_ContractFormViewState>();

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<ContractBloc>()
      ..add(const ContractListRequested('', refresh: true));
    _datasource = Modular.get<ContractDatasource>();
    loadFieldConfig('contracts'); // engine de campos configuráveis (decisão 7)
  }

  /// Vigência: "dd/mm/aaaa – dd/mm/aaaa" ou "Desde dd/mm/aaaa".
  static String _period(ContractListItem c) => c.dtEnd != null
      ? 'forms.contract.period'.tr(
          args: [isoDateToDisplay(c.dtStart), isoDateToDisplay(c.dtEnd)])
      : 'forms.contract.sinceStart'.tr(args: [isoDateToDisplay(c.dtStart)]);

  Widget _buildSearch(ContractListState state) =>
      RegisterSearchPage<ContractListItem>(
        title: 'register.listTitle'.tr(args: [widget.title]),
        // Engrenagem padrão da lista (Framework de Configurações, decisão 11)
        configModuleKey: 'contracts',
        items: state.items,
        loading: state.loading,
        avatarBuilder: (c) => '${c.id}',
        rowBuilder: (c) => [
          c.customerName ?? '',
          _period(c),
          'forms.contract.monthlyRow'.tr(args: [setesMoney(c.monthlyValue)]),
          c.active
              ? 'forms.contract.activeRow'.tr()
              : 'forms.contract.inactiveRow'.tr(),
        ],
        onFilterChanged: (filter) => _bloc.add(ContractListRequested(filter)),
        onNew: () => _bloc.add(const ContractNewPressed()),
        onView: (c) => _bloc.add(ContractEditPressed(c.id)),
      );

  Widget _buildForm(ContractFormState state) => _ContractFormView(
        key: _formViewKey,
        title: widget.title,
        state: state,
        datasource: _datasource,
        fieldConfig: fieldConfig,
        onSave: (event) => _bloc.add(event),
        onBack: () => _bloc.add(const ContractBackToListPressed()),
        onDelete: state.editing == null
            ? null
            : () => _bloc.add(ContractDeleteRequested(state.editing!.id)),
      );

  @override
  Widget build(BuildContext context) => BlocConsumer<ContractBloc, ContractState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is ContractActionSuccess || current is ContractActionFailure,
        // PONTE de feedback (Framework de Mensagens): a tela nunca chama
        // ScaffoldMessenger/AlertDialog — sucesso = SnackBar via ponte (R1);
        // falha = dialog, com fields[] do servidor ancorado no campo do
        // formulário quando ele está montado.
        listener: (context, state) {
          if (state is ContractActionSuccess) {
            showSuccessFeedback(context, state.messageKey);
            return;
          }
          final failure = (state as ContractActionFailure).failure;
          final form = _formViewKey.currentState;
          if (failure.fields.isNotEmpty && form != null) {
            form.showServerFieldError(failure);
          } else {
            showFailureFeedback(context, failure);
          }
        },
        buildWhen: (_, current) =>
            current is ContractListState || current is ContractFormState,
        builder: (context, state) => switch (state) {
          ContractFormState() => _buildForm(state),
          ContractListState() => _buildSearch(state),
          _ => _buildSearch(const ContractListState(loading: true)),
        },
      );
}

/// Form do contrato (SetesFormShell): cliente (lookup) + datas + dia de
/// vencimento + ativo + ITENS (produto × valor mensal) com total.
class _ContractFormView extends StatefulWidget {
  const _ContractFormView({
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
  final ContractFormState state;
  final ContractDatasource datasource;

  /// Catálogo resolvido da interface (tb_interface_has_field × cliente).
  final List<FieldConfigEntity> fieldConfig;
  final void Function(ContractSaveRequested event) onSave;
  final VoidCallback onBack;
  final VoidCallback? onDelete;

  @override
  State<_ContractFormView> createState() => _ContractFormViewState();
}

class _ContractFormViewState extends State<_ContractFormView> {
  late final TextEditingController _dtStart;
  late final TextEditingController _dtEnd;
  late final TextEditingController _paymentDay;

  // R3: foco programático + marca inline SÓ do campo pendente.
  final _dtStartFocus = FocusNode();
  final _dtEndFocus = FocusNode();
  final _paymentDayFocus = FocusNode();
  final _dtStartKey = GlobalKey<FormFieldState<String>>();
  final _dtEndKey = GlobalKey<FormFieldState<String>>();
  final _paymentDayKey = GlobalKey<FormFieldState<String>>();

  /// Cliente escolhido no lookup — id salvo, nome exibido (JOIN da API).
  int? _customerId;
  String _customerName = '';

  late bool _active;
  late List<ContractItem> _items;

  ContractFull? get _editing => widget.state.editing;

  /// Mensalidade = soma dos itens (derivada — a API nunca a recebe).
  double get _total =>
      _items.fold(0, (sum, item) => sum + item.value);

  @override
  void initState() {
    super.initState();
    final editing = _editing;
    _customerId   = editing?.customerId;
    _customerName = editing?.customerName ?? '';
    _dtStart = TextEditingController(text: isoDateToDisplay(editing?.dtStart));
    _dtEnd   = TextEditingController(text: isoDateToDisplay(editing?.dtEnd));
    _paymentDay =
        TextEditingController(text: '${editing?.paymentDay ?? 5}');
    _active = editing?.active ?? true;
    _items  = List.of(editing?.items ?? const []);
  }

  @override
  void dispose() {
    _dtStart.dispose();
    _dtEnd.dispose();
    _paymentDay.dispose();
    _dtStartFocus.dispose();
    _dtEndFocus.dispose();
    _paymentDayFocus.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Catálogo de campos (decisão 7): caption e required do cliente.
  // ------------------------------------------------------------------

  FieldConfigEntity? _cfg(String field) =>
      fieldConfigOf(widget.fieldConfig, field);

  String _label(String field, String i18nKey) =>
      _cfg(field)?.caption ?? i18nKey.tr();

  bool _requiredCfg(String field) => _cfg(field)?.required ?? false;

  Future<void> _pickCustomer() async {
    final picked = await showSetesLookup<ContractCustomerLookup>(
      context: context,
      title: 'lookup.customers'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: widget.datasource.customers,
      itemId: (c) => c.id,
      itemLabel: (c) => c.display,
    );
    if (picked != null) {
      setState(() {
        _customerId   = picked.id;
        _customerName = picked.display;
      });
    }
  }

  /// Dialog de item: incluir (produto via lookup + valor) ou editar o
  /// VALOR de um item existente (produto é a chave do sync — imutável).
  Future<void> _openItemDialog({ContractItem? existing}) async {
    final result = await showDialog<ContractItem>(
      context: context,
      builder: (_) => _ContractItemDialog(
        datasource: widget.datasource,
        existing: existing,
        fieldConfig: widget.fieldConfig,
        usedProductIds: {
          for (final item in _items)
            if (item.productId != existing?.productId) item.productId,
        },
      ),
    );
    if (result == null) return;
    setState(() {
      final index =
          _items.indexWhere((item) => item.productId == result.productId);
      if (index >= 0) {
        _items[index] = result;
      } else {
        _items.add(result);
      }
    });
  }

  // ------------------------------------------------------------------
  // Validação (R3/R6): catálogo + DTO como fontes; validators servem o
  // inline (SetesTextField) E a cadeia uma-pendência-por-vez do salvar.
  // ------------------------------------------------------------------

  String? _validateDtStart(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'register.requiredField'
          .tr(args: [_label('dt_start', 'forms.contract.dtStart')]);
    }
    return displayDateToIso(text) == null ? 'register.invalidDate'.tr() : null;
  }

  String? _validateDtEnd(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return _requiredCfg('dt_end')
          ? 'register.requiredField'
              .tr(args: [_label('dt_end', 'forms.contract.dtEnd')])
          : null;
    }
    final iso = displayDateToIso(text);
    if (iso == null) return 'register.invalidDate'.tr();
    final startIso = displayDateToIso(_dtStart.text);
    // ISO compara cronologicamente como string.
    if (startIso != null && iso.compareTo(startIso) < 0) {
      return 'forms.contract.dtEndBeforeStart'.tr();
    }
    return null;
  }

  String? _validatePaymentDay(String? value) {
    final day = int.tryParse(value?.trim() ?? '');
    if (day == null || day < 1 || day > 28) {
      return 'forms.contract.paymentDayInvalid'.tr();
    }
    return null;
  }

  /// Campos NA ORDEM da tela (R3). Os names casam com o payload da API —
  /// é por eles que o fields[] do servidor ancora no campo.
  List<PendencyField> get _pendencyFields => [
        PendencyField(
          name: 'customerId',
          validate: () => _customerId == null
              ? 'register.requiredField'.tr(
                  args: [_label('tb_customer_id', 'forms.contract.customer')])
              : null,
        ),
        PendencyField(
          name: 'dtStart',
          focusNode: _dtStartFocus,
          fieldKey: _dtStartKey,
          validate: () => _validateDtStart(_dtStart.text),
        ),
        PendencyField(
          name: 'dtEnd',
          focusNode: _dtEndFocus,
          fieldKey: _dtEndKey,
          validate: () => _validateDtEnd(_dtEnd.text),
        ),
        PendencyField(
          name: 'paymentDay',
          focusNode: _paymentDayFocus,
          fieldKey: _paymentDayKey,
          validate: () => _validatePaymentDay(_paymentDay.text),
        ),
        PendencyField(
          name: 'items',
          validate: () =>
              _items.isEmpty ? 'forms.contract.noItems'.tr() : null,
        ),
      ];

  /// Ancora o fields[] do envelope 400/409 no campo (chamado pelo listener
  /// do bloc via GlobalKey — equivalente local da fábrica).
  Future<void> showServerFieldError(Failure failure) =>
      showServerFieldFeedback(context, failure, _pendencyFields);

  Future<void> _save() async {
    if (!await ensureNoPendency(context, _pendencyFields)) return;
    widget.onSave(ContractSaveRequested(
      editingId: _editing?.id,
      input: ContractInput(
        customerId: _customerId!,
        dtStart:    displayDateToIso(_dtStart.text)!,
        dtEnd:      displayDateToIso(_dtEnd.text),
        paymentDay: int.parse(_paymentDay.text.trim()),
        active:     _active,
        items:      _items,
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

  /// Seção de itens (D9): lista local + adicionar/editar/remover; o total
  /// (mensalidade) atualiza a cada mudança. Fora da sequência de Tab.
  Widget _buildItemsSection(BuildContext context) => ExcludeFocusTraversal(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SetesText.title('forms.contract.items'.tr()),
            const SizedBox(height: 8),
            if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SetesText('register.emptyList'.tr()),
              )
            else
              ...[
                for (final item in _items) ...[
                  SetesListTile(
                    leading: CircleAvatar(
                        child: SetesText('${item.productId}')),
                    title: SetesText(item.productDescription ?? ''),
                    subtitle: SetesText(setesMoney(item.value)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'forms.contract.editItem'.tr(),
                          onPressed: () => _openItemDialog(existing: item),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'forms.contract.removeItem'.tr(),
                          onPressed: () =>
                              setState(() => _items.remove(item)),
                        ),
                      ],
                    ),
                    onTap: () => _openItemDialog(existing: item),
                  ),
                  const Divider(height: 1),
                ],
              ],
            const SizedBox(height: 8),
            SetesButton(
              label: 'forms.contract.addItem'.tr(),
              icon: Icons.add,
              onPressed: () => _openItemDialog(),
            ),
            const SizedBox(height: 12),
            SetesText(
              'forms.contract.monthlyRow'.tr(args: [setesMoney(_total)]),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    // Tabulação (criar-formulario-cadastro.md, item 8): Tab só nos campos
    // editáveis na ordem declarada; lookup, checkbox e itens ficam fora.
    var order = 0;
    Widget field(Widget child) =>
        FocusTraversalOrder(order: NumericFocusOrder((++order).toDouble()), child: child);

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
              label: _label('tb_customer_id', 'forms.contract.customer'),
              display: _customerName,
              onSearch: _pickCustomer,
              onClear: () => setState(() {
                _customerId = null;
                _customerName = '';
              }),
            ),
            const SizedBox(height: 16),
            field(SetesTextField(
              label: _label('dt_start', 'forms.contract.dtStart'),
              hint: 'register.dateHint'.tr(),
              controller: _dtStart,
              focusNode: _dtStartFocus,
              fieldKey: _dtStartKey,
              autofocus: true,
              textInputAction: TextInputAction.next,
              validator: _validateDtStart,
            )),
            const SizedBox(height: 16),
            field(SetesTextField(
              label: _label('dt_end', 'forms.contract.dtEnd'),
              hint: 'register.dateHint'.tr(),
              controller: _dtEnd,
              focusNode: _dtEndFocus,
              fieldKey: _dtEndKey,
              textInputAction: TextInputAction.next,
              validator: _validateDtEnd,
            )),
            const SizedBox(height: 16),
            field(SetesTextField(
              label: _label('payment_day', 'forms.contract.paymentDay'),
              hint: 'forms.contract.paymentDayHint'.tr(),
              controller: _paymentDay,
              focusNode: _paymentDayFocus,
              fieldKey: _paymentDayKey,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              validator: _validatePaymentDay,
            )),
            const SizedBox(height: 8),
            ExcludeFocusTraversal(
              child: SetesCheckbox(
                label: _label('active', 'forms.contract.active'),
                value: _active,
                onChanged: (checked) =>
                    setState(() => _active = checked ?? true),
              ),
            ),
            const SizedBox(height: 16),
            _buildItemsSection(context),
          ],
        ),
      ),
    );
  }
}

/// Dialog de item do contrato: produto (lookup dos ATIVOS) + valor mensal.
/// Na edição o produto é travado (chave do sync por productId) — só o
/// valor muda. Devolve o [ContractItem] via Navigator.pop. Validação
/// interna também uma-pendência-por-vez via ponte (R3).
class _ContractItemDialog extends StatefulWidget {
  const _ContractItemDialog({
    required this.datasource,
    required this.usedProductIds,
    required this.fieldConfig,
    this.existing,
  });

  final ContractDatasource datasource;

  /// Produtos já usados nos DEMAIS itens (produto não pode repetir).
  final Set<int> usedProductIds;

  /// Catálogo da interface — captions do cliente também nos campos do item.
  final List<FieldConfigEntity> fieldConfig;
  final ContractItem? existing;

  @override
  State<_ContractItemDialog> createState() => _ContractItemDialogState();
}

class _ContractItemDialogState extends State<_ContractItemDialog> {
  late final TextEditingController _value;
  final _valueFocus = FocusNode();
  final _valueKey = GlobalKey<FormFieldState<String>>();

  int? _productId;
  String _productDescription = '';

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _productId          = widget.existing?.productId;
    _productDescription = widget.existing?.productDescription ?? '';
    _value = TextEditingController(
        text: widget.existing == null
            ? ''
            : widget.existing!.value.toStringAsFixed(2).replaceAll('.', ','));
  }

  @override
  void dispose() {
    _value.dispose();
    _valueFocus.dispose();
    super.dispose();
  }

  String _label(String field, String i18nKey) =>
      fieldConfigOf(widget.fieldConfig, field)?.caption ?? i18nKey.tr();

  Future<void> _pickProduct() async {
    final picked = await showSetesLookup<ContractProductLookup>(
      context: context,
      title: 'lookup.products'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: widget.datasource.products,
      itemId: (p) => p.id,
      itemLabel: (p) => p.description,
    );
    if (picked != null) {
      setState(() {
        _productId          = picked.id;
        _productDescription = picked.description;
      });
    }
  }

  String? _validateValue(String? value) {
    final parsed =
        double.tryParse((value ?? '').trim().replaceAll(',', '.'));
    if (parsed == null || parsed < 0) {
      return 'forms.contract.itemValueInvalid'.tr();
    }
    return null;
  }

  /// Uma pendência por vez também no dialog de sub-lista (R3): produto
  /// obrigatório e sem repetição, valor >= 0 — mesma mecânica da ponte.
  Future<void> _confirm() async {
    final ok = await ensureNoPendency(context, [
      PendencyField(
        name: 'productId',
        validate: () {
          if (_productId == null) {
            return 'register.requiredField'.tr(
                args: [_label('tb_product_id', 'forms.contract.product')]);
          }
          if (widget.usedProductIds.contains(_productId)) {
            return 'forms.contract.duplicateProduct'.tr();
          }
          return null;
        },
      ),
      PendencyField(
        name: 'value',
        focusNode: _valueFocus,
        fieldKey: _valueKey,
        validate: () => _validateValue(_value.text),
      ),
    ]);
    if (!ok || !mounted) return;
    Navigator.of(context).pop(ContractItem(
      productId:          _productId!,
      productDescription: _productDescription,
      value:              double.parse(_value.text.trim().replaceAll(',', '.')),
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: SetesText(_editing
            ? 'forms.contract.editItem'.tr()
            : 'forms.contract.addItem'.tr()),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_editing)
                SetesTextField(
                  key: ValueKey('product-locked-$_productId'),
                  label: _label('tb_product_id', 'forms.contract.product'),
                  controller:
                      TextEditingController(text: _productDescription),
                  readOnly: true,
                )
              else
                SetesLookupField(
                  label: _label('tb_product_id', 'forms.contract.product'),
                  display: _productDescription,
                  onSearch: _pickProduct,
                ),
              const SizedBox(height: 16),
              SetesTextField(
                label: _label('value', 'forms.contract.itemValue'),
                controller: _value,
                focusNode: _valueFocus,
                fieldKey: _valueKey,
                autofocus: _editing,
                keyboardType: TextInputType.number,
                validator: _validateValue,
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
            label: 'register.save'.tr(),
            kind: SetesButtonKind.text,
            onPressed: _confirm,
          ),
        ],
      );
}
