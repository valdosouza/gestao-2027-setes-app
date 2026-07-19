import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/entity/widgets/entity_date.dart';
import '../../../../shared/format/money.dart';
import '../../data/datasource/service_order_datasource.dart';
import '../../domain/entity/service_order_entity.dart';
import '../bloc/service_order_bloc.dart';

/// Tela de Ordens de Serviço — interface 'service-orders', grupo Serviços
/// (Módulo Software House, Onda 4). 1ª TELA DE PROCESSO do produto — FOGE
/// do molde lista+form: LISTA em abas Abertas × Faturadas (consulta por
/// status na API) com Rotina Mensal na AppBar e FAB "Abrir OS" (lookup de
/// cliente); tap na linha abre o DETALHE da OS — aberta permite itens
/// (incluir/editar/remover — o totalizer recalcula no servidor), cancelar
/// e GERAR FATURAMENTO (forma de pagamento + parcelas + vencimento
/// decidido pelo usuário — DP1); faturada é somente leitura.
class ServiceOrderPage extends StatefulWidget {
  const ServiceOrderPage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das telas.
  final String title;

  @override
  State<ServiceOrderPage> createState() => _ServiceOrderPageState();
}

class _ServiceOrderPageState extends State<ServiceOrderPage>
    with SingleTickerProviderStateMixin {
  late final ServiceOrderBloc _bloc;
  late final ServiceOrderDatasource _datasource;
  late final TabController _tabs;
  final _filter = TextEditingController();

  static const _statuses = ['A', 'F'];

  /// Aba refletida na tela — evita reload redundante quando o BLoC muda a
  /// aba sozinho (ex.: pós-faturamento cai em Faturadas).
  String _status = 'A';

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<ServiceOrderBloc>()
      ..add(const ServiceOrderListRequested(status: 'A', filter: ''));
    _datasource = Modular.get<ServiceOrderDatasource>();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      final status = _statuses[_tabs.index];
      if (status != _status) {
        _status = status;
        _bloc.add(ServiceOrderListRequested(status: status));
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _filter.dispose();
    super.dispose();
  }

  /// Engrenagem padrão da lista (Framework de Configurações, decisão 11) —
  /// replicada manualmente porque a tela de processo não usa a fábrica.
  void _openConfigs() {
    Modular.to.navigate('/home/interface-configs/', arguments: {
      'title': trCatalog('interface-configs', 'Interface Configs',
          prefix: 'menu.interfaces'),
      'moduleKey': 'service-orders',
      'returnTo': Modular.to.path,
    });
  }

  // -------------------------------------------------------------------
  // Ações da lista
  // -------------------------------------------------------------------

  /// FAB "Abrir OS": lookup de cliente → POST (409 da trava D5 vira
  /// SnackBar com a mensagem da API, via one-shot do bloc).
  Future<void> _openNewOrder() async {
    final picked = await showSetesLookup<ServiceCustomerLookup>(
      context: context,
      title: 'lookup.customers'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: _datasource.customers,
      itemId: (c) => c.id,
      itemLabel: (c) => c.display,
    );
    if (picked != null) {
      _bloc.add(ServiceOrderOpenRequested(picked.id));
    }
  }

  /// Rotina Mensal: dialog Mês/Ano → POST /monthly-run (o relatório volta
  /// no one-shot [ServiceOrderMonthlyRunDone]).
  Future<void> _openMonthlyRun() async {
    final competence = await showDialog<(int, int)>(
      context: context,
      builder: (_) => const _MonthlyRunDialog(),
    );
    if (competence != null) {
      _bloc.add(ServiceOrderMonthlyRunRequested(
          year: competence.$1, month: competence.$2));
    }
  }

  Future<void> _showMonthlyReport(MonthlyRunReport report) => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: SetesText('forms.serviceOrder.monthlyReportTitle'.tr()),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SetesText('forms.serviceOrder.reportProcessed'
                      .tr(args: ['${report.processed}'])),
                  const SizedBox(height: 4),
                  SetesText('forms.serviceOrder.reportOpened'
                      .tr(args: ['${report.opened}'])),
                  const SizedBox(height: 4),
                  SetesText('forms.serviceOrder.reportInjected'
                      .tr(args: ['${report.injected}'])),
                  const SizedBox(height: 4),
                  SetesText('forms.serviceOrder.reportSkipped'
                      .tr(args: ['${report.skipped}'])),
                  if (report.errors.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SetesText.title('forms.serviceOrder.reportErrors'.tr()),
                    const SizedBox(height: 4),
                    for (final error in report.errors)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: SetesText('forms.serviceOrder.reportErrorRow'
                            .tr(args: ['${error.customerId}', error.message])),
                      ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            SetesButton(
              label: 'register.close'.tr(),
              kind: SetesButtonKind.text,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        ),
      );

  // -------------------------------------------------------------------
  // Lista (abas Abertas × Faturadas)
  // -------------------------------------------------------------------

  Widget _buildList(ServiceOrderListState state) {
    _status = state.status;
    final tabIndex = _statuses.indexOf(state.status);
    if (_tabs.index != tabIndex) _tabs.index = tabIndex;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('register.listTitle'.tr(args: [widget.title])),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            tooltip: 'forms.serviceOrder.monthlyRun'.tr(),
            onPressed: _openMonthlyRun,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'register.configTooltip'.tr(),
            onPressed: _openConfigs,
          ),
        ],
      ),
      // FAB = Abrir OS (lookup de cliente + POST — padrão Icons.add)
      floatingActionButton: FloatingActionButton(
        tooltip: 'forms.serviceOrder.openOs'.tr(),
        onPressed: _openNewOrder,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Abas no CORPO (mesmo padrão de categories — no bottom da
          // AppBar as cores do tema sumiam no fundo primário).
          TabBar(
            controller: _tabs,
            tabs: [
              Tab(text: 'forms.serviceOrder.tabOpen'.tr()),
              Tab(text: 'forms.serviceOrder.tabInvoiced'.tr()),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SetesTextField(
                    label: 'register.filter'.tr(),
                    hint: 'register.filterHint'.tr(),
                    controller: _filter,
                    suffixIcon: Icons.search,
                    onSuffixPressed: _search,
                    onSubmitted: (_) => _search(),
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: _buildListBody(state)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _search() =>
      _bloc.add(ServiceOrderListRequested(filter: _filter.text.trim()));

  Widget _buildListBody(ServiceOrderListState state) {
    if (state.loading) return const SetesCircularProgressIndicator();
    if (state.items.isEmpty) {
      return Center(child: SetesText('register.emptyList'.tr()));
    }
    return ListView.separated(
      itemCount: state.items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final order = state.items[index];
        final cells = [
          isoDateToDisplay(order.dtRecord),
          'forms.serviceOrder.itemsCountRow'.tr(args: ['${order.itemsCount}']),
          'forms.serviceOrder.totalRow'
              .tr(args: [setesMoney(order.totalValue)]),
        ].where((cell) => cell.isNotEmpty);
        return SetesListTile(
          leading:
              CircleAvatar(child: SetesText('${order.number ?? order.id}')),
          title: SetesText(order.customerName ?? ''),
          subtitle: SetesText(cells.join(' · ')),
          onTap: () => _bloc.add(ServiceOrderViewRequested(order.id)),
        );
      },
    );
  }

  // -------------------------------------------------------------------
  // Detalhe da OS
  // -------------------------------------------------------------------

  Widget _buildDetail(ServiceOrderDetailState state) => _ServiceOrderDetailView(
        key: ValueKey('service-order-${state.order.id}'),
        title: widget.title,
        state: state,
        datasource: _datasource,
        onBack: () => _bloc.add(const ServiceOrderBackToListPressed()),
        onCancel: () =>
            _bloc.add(ServiceOrderCancelRequested(state.order.id)),
        onItemSave: (itemId, input) => _bloc.add(ServiceOrderItemSaveRequested(
            orderId: state.order.id, itemId: itemId, input: input)),
        onItemRemove: (itemId) => _bloc.add(ServiceOrderItemRemoveRequested(
            orderId: state.order.id, itemId: itemId)),
        onInvoice: (input) => _bloc.add(ServiceOrderInvoiceRequested(
            orderId: state.order.id, input: input)),
      );

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<ServiceOrderBloc, ServiceOrderState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is ServiceOrderActionSuccess ||
            current is ServiceOrderActionFailure ||
            current is ServiceOrderMonthlyRunDone,
        listener: (context, state) {
          if (state is ServiceOrderMonthlyRunDone) {
            _showMonthlyReport(state.report);
            return;
          }
          final message = state is ServiceOrderActionSuccess
              ? (state.args.isEmpty
                  ? state.messageKey.tr()
                  : state.messageKey.tr(args: state.args))
              : (state as ServiceOrderActionFailure).message;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: SetesText(message)));
        },
        buildWhen: (_, current) =>
            current is ServiceOrderListState ||
            current is ServiceOrderDetailState,
        builder: (context, state) => switch (state) {
          ServiceOrderDetailState() => _buildDetail(state),
          ServiceOrderListState() => _buildList(state),
          _ => _buildList(const ServiceOrderListState(loading: true)),
        },
      );
}

/// Quantidade sem zeros à direita ('2' / '1,5') — pt-BR usa vírgula.
String _quantityText(double quantity) =>
    quantity == quantity.roundToDouble()
        ? '${quantity.toInt()}'
        : quantity.toString().replaceAll('.', ',');

/// Detalhe da OS: cabeçalho (cliente/nº/data/status/total), itens e — na
/// ABERTA — ações de item, Cancelar OS (delete_outline na AppBar) e o
/// botão primário Gerar Faturamento. FATURADA é somente leitura, com nº
/// da fatura e data de emissão.
class _ServiceOrderDetailView extends StatelessWidget {
  const _ServiceOrderDetailView({
    required this.title,
    required this.state,
    required this.datasource,
    required this.onBack,
    required this.onCancel,
    required this.onItemSave,
    required this.onItemRemove,
    required this.onInvoice,
    super.key,
  });

  final String title;
  final ServiceOrderDetailState state;
  final ServiceOrderDatasource datasource;
  final VoidCallback onBack;
  final VoidCallback onCancel;
  final void Function(int? itemId, ServiceOrderItemInput input) onItemSave;
  final void Function(int itemId) onItemRemove;
  final void Function(ServiceOrderInvoiceInput input) onInvoice;

  ServiceOrderFull get order => state.order;
  bool get busy => state.saving;

  Future<void> _confirmCancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: SetesText('forms.serviceOrder.confirmCancel'.tr()),
        actions: [
          SetesButton(
            label: 'register.cancel'.tr(),
            kind: SetesButtonKind.text,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          SetesButton(
            label: 'forms.serviceOrder.cancelOs'.tr(),
            kind: SetesButtonKind.text,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed == true) onCancel();
  }

  Future<void> _openItemDialog(BuildContext context,
      {ServiceOrderItem? existing}) async {
    final input = await showDialog<ServiceOrderItemInput>(
      context: context,
      builder: (_) =>
          _ServiceOrderItemDialog(datasource: datasource, existing: existing),
    );
    if (input != null) onItemSave(existing?.id, input);
  }

  Future<void> _confirmRemoveItem(
      BuildContext context, ServiceOrderItem item) async {
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
    if (confirmed == true) onItemRemove(item.id);
  }

  Future<void> _openInvoiceDialog(BuildContext context) async {
    final input = await showDialog<ServiceOrderInvoiceInput>(
      context: context,
      builder: (_) => _InvoiceDialog(datasource: datasource),
    );
    if (input != null) onInvoice(input);
  }

  Widget _headerRow(String text, {TextStyle? style}) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: SetesText(text, style: style),
      );

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return SetesCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SetesText(
            order.customerName ?? '',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _headerRow('forms.serviceOrder.numberRow'
              .tr(args: ['${order.number ?? order.id}'])),
          _headerRow('forms.serviceOrder.dateRow'
              .tr(args: [isoDateToDisplay(order.dtRecord)])),
          _headerRow(order.isOpen
              ? 'forms.serviceOrder.statusOpen'.tr()
              : 'forms.serviceOrder.statusInvoiced'.tr()),
          if (!order.isOpen) ...[
            if (order.invoiceNumber != null)
              _headerRow('forms.serviceOrder.invoiceNumberRow'
                  .tr(args: [order.invoiceNumber!])),
            if (order.dtEmission != null)
              _headerRow('forms.serviceOrder.dtEmissionRow'
                  .tr(args: [isoDateToDisplay(order.dtEmission)])),
          ],
          const SizedBox(height: 8),
          // Total em destaque — recalculado no servidor a cada operação.
          SetesText(
            'forms.serviceOrder.totalRow'
                .tr(args: [setesMoney(order.totalValue)]),
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(BuildContext context, ServiceOrderItem item) {
    final discount = item.discountValue;
    final subtitle = discount > 0
        ? 'forms.serviceOrder.itemRowDiscount'.tr(args: [
            _quantityText(item.quantity),
            setesMoney(item.unitValue),
            setesMoney(discount),
            setesMoney(item.total),
          ])
        : 'forms.serviceOrder.itemRow'.tr(args: [
            _quantityText(item.quantity),
            setesMoney(item.unitValue),
            setesMoney(item.total),
          ]);
    return SetesListTile(
      leading: CircleAvatar(child: SetesText('${item.productId}')),
      title: SetesText(item.productDescription ?? ''),
      subtitle: SetesText(subtitle),
      trailing: order.isOpen
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'forms.serviceOrder.editItem'.tr(),
                  onPressed:
                      busy ? null : () => _openItemDialog(context, existing: item),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'forms.serviceOrder.removeItem'.tr(),
                  onPressed:
                      busy ? null : () => _confirmRemoveItem(context, item),
                ),
              ],
            )
          : null,
      onTap: order.isOpen && !busy
          ? () => _openItemDialog(context, existing: item)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: busy ? null : onBack,
          ),
          title: Text(title),
          actions: [
            if (order.isOpen)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'forms.serviceOrder.cancelOs'.tr(),
                onPressed: busy ? null : () => _confirmCancel(context),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            SetesText.title('forms.serviceOrder.items'.tr()),
            const SizedBox(height: 8),
            if (order.items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SetesText('register.emptyList'.tr()),
              )
            else
              for (final item in order.items) ...[
                _buildItemTile(context, item),
                const Divider(height: 1),
              ],
            if (order.isOpen) ...[
              const SizedBox(height: 8),
              SetesButton(
                label: 'forms.serviceOrder.addItem'.tr(),
                icon: Icons.add,
                onPressed: busy ? null : () => _openItemDialog(context),
              ),
              const SizedBox(height: 24),
              // Botão primário do processo: fatura interna + financeiro RA.
              SetesButton(
                label: 'forms.serviceOrder.generateInvoice'.tr(),
                icon: Icons.receipt_long_outlined,
                onPressed: busy ? null : () => _openInvoiceDialog(context),
              ),
            ],
          ],
        ),
      );
}

/// Dialog da Rotina Mensal: competência Mês (1–12, default corrente) +
/// Ano. Devolve (ano, mês) via Navigator.pop.
class _MonthlyRunDialog extends StatefulWidget {
  const _MonthlyRunDialog();

  @override
  State<_MonthlyRunDialog> createState() => _MonthlyRunDialogState();
}

class _MonthlyRunDialogState extends State<_MonthlyRunDialog> {
  late int _month;
  late final TextEditingController _year;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = now.month;
    _year = TextEditingController(text: '${now.year}');
  }

  @override
  void dispose() {
    _year.dispose();
    super.dispose();
  }

  void _warn(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: SetesText(message)));

  void _confirm() {
    final year = int.tryParse(_year.text.trim());
    if (year == null || year < 2020 || year > 2100) {
      _warn('forms.serviceOrder.yearInvalid'.tr());
      return;
    }
    Navigator.of(context).pop((year, _month));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: SetesText('forms.serviceOrder.monthlyRun'.tr()),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SetesDropdown<int>(
                label: 'forms.serviceOrder.month'.tr(),
                value: _month,
                items: const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
                itemLabel: (month) => month.toString().padLeft(2, '0'),
                onChanged: (month) =>
                    setState(() => _month = month ?? _month),
              ),
              const SizedBox(height: 16),
              SetesTextField(
                label: 'forms.serviceOrder.year'.tr(),
                controller: _year,
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
            label: 'forms.serviceOrder.run'.tr(),
            kind: SetesButtonKind.text,
            onPressed: _confirm,
          ),
        ],
      );
}

/// Dialog de item da OS: produto (lookup dos ATIVOS) + quantidade (>0,
/// default 1) + valor unitário (>=0) + desconto (>=0, opcional). Devolve
/// o [ServiceOrderItemInput] via Navigator.pop.
class _ServiceOrderItemDialog extends StatefulWidget {
  const _ServiceOrderItemDialog({required this.datasource, this.existing});

  final ServiceOrderDatasource datasource;
  final ServiceOrderItem? existing;

  @override
  State<_ServiceOrderItemDialog> createState() =>
      _ServiceOrderItemDialogState();
}

class _ServiceOrderItemDialogState extends State<_ServiceOrderItemDialog> {
  late final TextEditingController _quantity;
  late final TextEditingController _unitValue;
  late final TextEditingController _discountValue;

  int? _productId;
  String _productDescription = '';

  bool get _editing => widget.existing != null;

  static String _decimalText(double value) =>
      value.toStringAsFixed(2).replaceAll('.', ',');

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _productId          = existing?.productId;
    _productDescription = existing?.productDescription ?? '';
    _quantity = TextEditingController(
        text: existing == null ? '1' : _quantityText(existing.quantity));
    _unitValue = TextEditingController(
        text: existing == null ? '' : _decimalText(existing.unitValue));
    _discountValue = TextEditingController(
        text: existing == null || existing.discountValue == 0
            ? ''
            : _decimalText(existing.discountValue));
  }

  @override
  void dispose() {
    _quantity.dispose();
    _unitValue.dispose();
    _discountValue.dispose();
    super.dispose();
  }

  Future<void> _pickProduct() async {
    final picked = await showSetesLookup<ServiceProductLookup>(
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

  double? _parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  void _confirm() {
    if (_productId == null) {
      _warn('register.requiredField'
          .tr(args: ['forms.serviceOrder.product'.tr()]));
      return;
    }
    final quantity = _parse(_quantity.text);
    if (quantity == null || quantity <= 0) {
      _warn('forms.serviceOrder.quantityInvalid'.tr());
      return;
    }
    final unitValue = _parse(_unitValue.text);
    if (unitValue == null || unitValue < 0) {
      _warn('forms.serviceOrder.unitValueInvalid'.tr());
      return;
    }
    double? discountValue;
    if (_discountValue.text.trim().isNotEmpty) {
      discountValue = _parse(_discountValue.text);
      if (discountValue == null || discountValue < 0) {
        _warn('forms.serviceOrder.discountInvalid'.tr());
        return;
      }
    }
    Navigator.of(context).pop(ServiceOrderItemInput(
      productId:     _productId!,
      quantity:      quantity,
      unitValue:     unitValue,
      discountValue: discountValue,
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: SetesText(_editing
            ? 'forms.serviceOrder.editItem'.tr()
            : 'forms.serviceOrder.addItem'.tr()),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SetesLookupField(
                label: 'forms.serviceOrder.product'.tr(),
                display: _productDescription,
                onSearch: _pickProduct,
              ),
              const SizedBox(height: 16),
              SetesTextField(
                label: 'forms.serviceOrder.quantity'.tr(),
                controller: _quantity,
                autofocus: _editing,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              SetesTextField(
                label: 'forms.serviceOrder.unitValue'.tr(),
                controller: _unitValue,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              SetesTextField(
                label: 'forms.serviceOrder.discountValue'.tr(),
                controller: _discountValue,
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

/// Dialog Gerar Faturamento: forma de pagamento (lookup dos payment types
/// com enable='S'), parcelas (1–99, default 1) e vencimento pré-preenchido
/// com a SUGESTÃO da API (5º dia útil) porém LIVREMENTE editável — DP1:
/// o usuário decide. Devolve o [ServiceOrderInvoiceInput].
class _InvoiceDialog extends StatefulWidget {
  const _InvoiceDialog({required this.datasource});

  final ServiceOrderDatasource datasource;

  @override
  State<_InvoiceDialog> createState() => _InvoiceDialogState();
}

class _InvoiceDialogState extends State<_InvoiceDialog> {
  late final TextEditingController _parcels;
  final _dtExpiration = TextEditingController();

  int? _paymentTypeId;
  String _paymentTypeDescription = '';

  @override
  void initState() {
    super.initState();
    _parcels = TextEditingController(text: '1');
    _loadSuggestion();
  }

  @override
  void dispose() {
    _parcels.dispose();
    _dtExpiration.dispose();
    super.dispose();
  }

  /// Prefixa o vencimento com a sugestão do mês corrente (só o DEFAULT —
  /// DP1); falha da consulta deixa o campo vazio para o usuário digitar.
  Future<void> _loadSuggestion() async {
    try {
      final now = DateTime.now();
      final iso =
          await widget.datasource.expirationSuggestion(now.year, now.month);
      if (mounted && _dtExpiration.text.isEmpty) {
        _dtExpiration.text = isoDateToDisplay(iso);
      }
    } on Object {
      // Sugestão é opcional — o campo continua editável.
    }
  }

  Future<void> _pickPaymentType() async {
    final picked = await showSetesLookup<ServicePaymentTypeLookup>(
      context: context,
      title: 'lookup.paymentTypes'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      // A API não filtra — projeção local: só habilitadas (enable='S').
      onSearch: (filter) async {
        final all = await widget.datasource.paymentTypes();
        final lower = filter.toLowerCase();
        return [
          for (final pt in all)
            if (pt.enable &&
                (lower.isEmpty ||
                    pt.description.toLowerCase().contains(lower)))
              pt,
        ];
      },
      itemId: (pt) => pt.id,
      itemLabel: (pt) => pt.description,
    );
    if (picked != null) {
      setState(() {
        _paymentTypeId          = picked.id;
        _paymentTypeDescription = picked.description;
      });
    }
  }

  void _warn(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: SetesText(message)));

  void _confirm() {
    if (_paymentTypeId == null) {
      _warn('register.requiredField'
          .tr(args: ['forms.serviceOrder.paymentType'.tr()]));
      return;
    }
    final parcels = int.tryParse(_parcels.text.trim());
    if (parcels == null || parcels < 1 || parcels > 99) {
      _warn('forms.serviceOrder.parcelsInvalid'.tr());
      return;
    }
    final dtExpirationIso = displayDateToIso(_dtExpiration.text);
    if (dtExpirationIso == null) {
      _warn('register.invalidDate'.tr());
      return;
    }
    Navigator.of(context).pop(ServiceOrderInvoiceInput(
      dtExpiration:  dtExpirationIso,
      paymentTypeId: _paymentTypeId!,
      parcels:       parcels,
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: SetesText('forms.serviceOrder.generateInvoice'.tr()),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SetesLookupField(
                label: 'forms.serviceOrder.paymentType'.tr(),
                display: _paymentTypeDescription,
                onSearch: _pickPaymentType,
              ),
              const SizedBox(height: 16),
              SetesTextField(
                label: 'forms.serviceOrder.parcels'.tr(),
                controller: _parcels,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              SetesTextField(
                label: 'forms.serviceOrder.dtExpiration'.tr(),
                hint: 'register.dateHint'.tr(),
                controller: _dtExpiration,
                validator: validateOptionalDate,
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
            label: 'forms.serviceOrder.generateInvoice'.tr(),
            kind: SetesButtonKind.text,
            onPressed: _confirm,
          ),
        ],
      );
}
