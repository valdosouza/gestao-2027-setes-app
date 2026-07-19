import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/entity/widgets/entity_date.dart';
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
class ContractPage extends StatefulWidget {
  const ContractPage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das duas telas.
  final String title;

  @override
  State<ContractPage> createState() => _ContractPageState();
}

class _ContractPageState extends State<ContractPage> {
  late final ContractBloc _bloc;
  late final ContractDatasource _datasource;

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<ContractBloc>()
      ..add(const ContractListRequested('', refresh: true));
    _datasource = Modular.get<ContractDatasource>();
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
        key: ValueKey(state.editing?.id ?? 'contract-new'),
        title: widget.title,
        state: state,
        datasource: _datasource,
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
        listener: (context, state) {
          final message = state is ContractActionSuccess
              ? state.messageKey.tr()
              : (state as ContractActionFailure).message;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: SetesText(message)));
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
    required this.onSave,
    required this.onBack,
    required this.onDelete,
    super.key,
  });

  final String title;
  final ContractFormState state;
  final ContractDatasource datasource;
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
    super.dispose();
  }

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

  void _warn(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: SetesText(message)));

  void _save() {
    if (_customerId == null) {
      _warn('register.requiredField'
          .tr(args: ['forms.contract.customer'.tr()]));
      return;
    }
    if (_dtStart.text.trim().isEmpty) {
      _warn('register.requiredField'
          .tr(args: ['forms.contract.dtStart'.tr()]));
      return;
    }
    final dtStartIso = displayDateToIso(_dtStart.text);
    if (dtStartIso == null) {
      _warn('register.invalidDate'.tr());
      return;
    }
    String? dtEndIso;
    if (_dtEnd.text.trim().isNotEmpty) {
      dtEndIso = displayDateToIso(_dtEnd.text);
      if (dtEndIso == null) {
        _warn('register.invalidDate'.tr());
        return;
      }
      // ISO compara cronologicamente como string.
      if (dtEndIso.compareTo(dtStartIso) < 0) {
        _warn('forms.contract.dtEndBeforeStart'.tr());
        return;
      }
    }
    final paymentDay = int.tryParse(_paymentDay.text.trim());
    if (paymentDay == null || paymentDay < 1 || paymentDay > 28) {
      _warn('forms.contract.paymentDayInvalid'.tr());
      return;
    }
    if (_items.isEmpty) {
      _warn('forms.contract.noItems'.tr());
      return;
    }
    widget.onSave(ContractSaveRequested(
      editingId: _editing?.id,
      input: ContractInput(
        customerId: _customerId!,
        dtStart:    dtStartIso,
        dtEnd:      dtEndIso,
        paymentDay: paymentDay,
        active:     _active,
        items:      _items,
      ),
    ));
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: SetesText('register.confirmDelete'.tr()),
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
              label: 'forms.contract.customer'.tr(),
              display: _customerName,
              onSearch: _pickCustomer,
              onClear: () => setState(() {
                _customerId = null;
                _customerName = '';
              }),
            ),
            const SizedBox(height: 16),
            field(SetesTextField(
              label: 'forms.contract.dtStart'.tr(),
              hint: 'register.dateHint'.tr(),
              controller: _dtStart,
              autofocus: true,
              textInputAction: TextInputAction.next,
              validator: validateOptionalDate,
            )),
            const SizedBox(height: 16),
            field(SetesTextField(
              label: 'forms.contract.dtEnd'.tr(),
              hint: 'register.dateHint'.tr(),
              controller: _dtEnd,
              textInputAction: TextInputAction.next,
              validator: validateOptionalDate,
            )),
            const SizedBox(height: 16),
            field(SetesTextField(
              label: 'forms.contract.paymentDay'.tr(),
              hint: 'forms.contract.paymentDayHint'.tr(),
              controller: _paymentDay,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
            )),
            const SizedBox(height: 8),
            ExcludeFocusTraversal(
              child: SetesCheckbox(
                label: 'forms.contract.active'.tr(),
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
/// valor muda. Devolve o [ContractItem] via Navigator.pop.
class _ContractItemDialog extends StatefulWidget {
  const _ContractItemDialog({
    required this.datasource,
    required this.usedProductIds,
    this.existing,
  });

  final ContractDatasource datasource;

  /// Produtos já usados nos DEMAIS itens (produto não pode repetir).
  final Set<int> usedProductIds;
  final ContractItem? existing;

  @override
  State<_ContractItemDialog> createState() => _ContractItemDialogState();
}

class _ContractItemDialogState extends State<_ContractItemDialog> {
  late final TextEditingController _value;

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
    super.dispose();
  }

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

  void _warn(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: SetesText(message)));

  void _confirm() {
    if (_productId == null) {
      _warn(
          'register.requiredField'.tr(args: ['forms.contract.product'.tr()]));
      return;
    }
    if (widget.usedProductIds.contains(_productId)) {
      _warn('forms.contract.duplicateProduct'.tr());
      return;
    }
    final value =
        double.tryParse(_value.text.trim().replaceAll(',', '.'));
    if (value == null || value < 0) {
      _warn('forms.contract.itemValueInvalid'.tr());
      return;
    }
    Navigator.of(context).pop(ContractItem(
      productId:          _productId!,
      productDescription: _productDescription,
      value:              value,
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
                  label: 'forms.contract.product'.tr(),
                  controller:
                      TextEditingController(text: _productDescription),
                  readOnly: true,
                )
              else
                SetesLookupField(
                  label: 'forms.contract.product'.tr(),
                  display: _productDescription,
                  onSearch: _pickProduct,
                ),
              const SizedBox(height: 16),
              SetesTextField(
                label: 'forms.contract.itemValue'.tr(),
                controller: _value,
                autofocus: _editing,
                keyboardType: TextInputType.number,
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
