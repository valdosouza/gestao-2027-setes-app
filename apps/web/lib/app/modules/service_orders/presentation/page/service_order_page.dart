import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/entity/widgets/entity_date.dart';
import '../../../../shared/feedback/feedback.dart';
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
  /// dialog de validação com a mensagem da API, via one-shot + ponte).
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

  /// RELATÓRIO da rotina mensal — dialog INFORMATIVO próprio (estrutura de
  /// linhas + erros por cliente), mantido fora da ponte por decisão do
  /// framework (Onda B): não é feedback de desfecho simples.
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
        // PONTE de feedback (Framework de Mensagens): a tela nunca chama
        // ScaffoldMessenger/AlertDialog para desfecho — sucesso = SnackBar
        // via ponte (R1); falha = dialog (os 409 de negócio — trava D5,
        // ordem faturada — viram validação com a mensagem da API); 400 com
        // fields[] mostra a message do campo apontado (o dialog de ação já
        // fechou — sem campo montado para focar).
        listener: (context, state) {
          if (state is ServiceOrderMonthlyRunDone) {
            _showMonthlyReport(state.report);
            return;
          }
          if (state is ServiceOrderActionSuccess) {
            showSuccessFeedback(context, state.messageKey,
                args: state.args.isEmpty ? null : state.args);
            return;
          }
          final failure = (state as ServiceOrderActionFailure).failure;
          if (failure.fields.isNotEmpty) {
            showValidationFeedback(context, failure.fields.first.message.tr());
          } else {
            showFailureFeedback(context, failure);
          }
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

/// Checagem de UM campo de dialog de ação: [validate] devolve a chave i18n
/// (ou texto pronto) da pendência; [focusNode]/[fieldKey] ancoram o retorno
/// do foco e a marca inline SÓ nele.
class _DialogCheck {
  const _DialogCheck({required this.validate, this.focusNode, this.fieldKey});

  final String? Function() validate;
  final FocusNode? focusNode;
  final GlobalKey<FormFieldState<String>>? fieldKey;
}

/// R3 — UMA pendência por vez nos dialogs de ação (mesma mecânica da
/// fábrica register_form_page): percorre as checagens NA ORDEM declarada
/// e, na PRIMEIRA mensagem, mostra o dialog da ponte → OK → marca SÓ o
/// campo pendente e devolve o foco a ele. true = tudo passou.
Future<bool> _firstPendingCheck(
    BuildContext context, List<_DialogCheck> checks) async {
  for (final check in checks) {
    final message = check.validate();
    if (message != null) {
      // .tr() em texto já traduzido devolve o próprio texto.
      await showValidationFeedback(context, message.tr());
      if (context.mounted) {
        check.fieldKey?.currentState?.validate();
        check.focusNode?.requestFocus();
      }
      return false;
    }
  }
  return true;
}

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

  /// Cancelamento confirmado via decisão TIPADA da ponte (R4): Sim =
  /// cancelar a OS; Cancelar (ou fechar) = nada. Sem ação alternativa →
  /// sem botão Não.
  Future<void> _confirmCancel(BuildContext context) async {
    final decision = await askDecision(
      context,
      message: 'forms.serviceOrder.confirmCancel'.tr(),
      yesLabel: 'forms.serviceOrder.cancelOs'.tr(),
    );
    if (decision == SetesDecision.yes) onCancel();
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

  /// Remoção de item confirmada via decisão TIPADA da ponte (R4).
  Future<void> _confirmRemoveItem(
      BuildContext context, ServiceOrderItem item) async {
    final decision = await askDecision(
      context,
      message: 'register.confirmDelete'.tr(),
      yesLabel: 'register.delete'.tr(),
    );
    if (decision == SetesDecision.yes) onItemRemove(item.id);
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
  final _yearFocus = FocusNode();
  final _yearKey = GlobalKey<FormFieldState<String>>();

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
    _yearFocus.dispose();
    super.dispose();
  }

  String? _validateYear(String? value) {
    final year = int.tryParse(value?.trim() ?? '');
    return (year == null || year < 2020 || year > 2100)
        ? 'forms.serviceOrder.yearInvalid'
        : null;
  }

  /// Valida via ponte — R3: UMA pendência por vez com foco no campo.
  Future<void> _confirm() async {
    final ok = await _firstPendingCheck(context, [
      _DialogCheck(
        validate: () => _validateYear(_year.text),
        focusNode: _yearFocus,
        fieldKey: _yearKey,
      ),
    ]);
    if (!ok || !mounted) return;
    Navigator.of(context).pop((int.parse(_year.text.trim()), _month));
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
                focusNode: _yearFocus,
                fieldKey: _yearKey,
                keyboardType: TextInputType.number,
                validator: (value) => _validateYear(value)?.tr(),
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
  final _quantityFocus = FocusNode();
  final _unitValueFocus = FocusNode();
  final _discountValueFocus = FocusNode();
  final _quantityKey = GlobalKey<FormFieldState<String>>();
  final _unitValueKey = GlobalKey<FormFieldState<String>>();
  final _discountValueKey = GlobalKey<FormFieldState<String>>();

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
    _quantityFocus.dispose();
    _unitValueFocus.dispose();
    _discountValueFocus.dispose();
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

  double? _parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  String? _validateQuantity(String? value) {
    final quantity = _parse(value ?? '');
    return (quantity == null || quantity <= 0)
        ? 'forms.serviceOrder.quantityInvalid'
        : null;
  }

  String? _validateUnitValue(String? value) {
    final unitValue = _parse(value ?? '');
    return (unitValue == null || unitValue < 0)
        ? 'forms.serviceOrder.unitValueInvalid'
        : null;
  }

  /// Desconto é OPCIONAL — válido SE preenchido (convenção setes_validators).
  String? _validateDiscount(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final discount = _parse(value);
    return (discount == null || discount < 0)
        ? 'forms.serviceOrder.discountInvalid'
        : null;
  }

  /// Valida via ponte — R3: UMA pendência por vez, na ORDEM dos campos,
  /// com foco no pendente (o lookup de produto não recebe foco/marca —
  /// padrão da fábrica para FK).
  Future<void> _confirm() async {
    final ok = await _firstPendingCheck(context, [
      _DialogCheck(
        validate: () => _productId == null
            ? 'register.requiredField'
                .tr(args: ['forms.serviceOrder.product'.tr()])
            : null,
      ),
      _DialogCheck(
        validate: () => _validateQuantity(_quantity.text),
        focusNode: _quantityFocus,
        fieldKey: _quantityKey,
      ),
      _DialogCheck(
        validate: () => _validateUnitValue(_unitValue.text),
        focusNode: _unitValueFocus,
        fieldKey: _unitValueKey,
      ),
      _DialogCheck(
        validate: () => _validateDiscount(_discountValue.text),
        focusNode: _discountValueFocus,
        fieldKey: _discountValueKey,
      ),
    ]);
    if (!ok || !mounted) return;
    Navigator.of(context).pop(ServiceOrderItemInput(
      productId:     _productId!,
      quantity:      _parse(_quantity.text)!,
      unitValue:     _parse(_unitValue.text)!,
      discountValue: _discountValue.text.trim().isEmpty
          ? null
          : _parse(_discountValue.text),
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
                focusNode: _quantityFocus,
                fieldKey: _quantityKey,
                autofocus: _editing,
                keyboardType: TextInputType.number,
                validator: (value) => _validateQuantity(value)?.tr(),
              ),
              const SizedBox(height: 16),
              SetesTextField(
                label: 'forms.serviceOrder.unitValue'.tr(),
                controller: _unitValue,
                focusNode: _unitValueFocus,
                fieldKey: _unitValueKey,
                keyboardType: TextInputType.number,
                validator: (value) => _validateUnitValue(value)?.tr(),
              ),
              const SizedBox(height: 16),
              SetesTextField(
                label: 'forms.serviceOrder.discountValue'.tr(),
                controller: _discountValue,
                focusNode: _discountValueFocus,
                fieldKey: _discountValueKey,
                keyboardType: TextInputType.number,
                validator: (value) => _validateDiscount(value)?.tr(),
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
  final _parcelsFocus = FocusNode();
  final _dtExpirationFocus = FocusNode();
  final _parcelsKey = GlobalKey<FormFieldState<String>>();
  final _dtExpirationKey = GlobalKey<FormFieldState<String>>();

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
    _parcelsFocus.dispose();
    _dtExpirationFocus.dispose();
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

  String? _validateParcels(String? value) {
    final parcels = int.tryParse(value?.trim() ?? '');
    return (parcels == null || parcels < 1 || parcels > 99)
        ? 'forms.serviceOrder.parcelsInvalid'
        : null;
  }

  /// Vencimento é OBRIGATÓRIO na decisão do faturamento (vazio = inválido).
  String? _validateDtExpiration(String? value) =>
      displayDateToIso(value ?? '') == null ? 'register.invalidDate' : null;

  /// Valida via ponte — R3: UMA pendência por vez, na ORDEM dos campos,
  /// com foco no pendente (lookup de forma de pagamento sem foco/marca).
  Future<void> _confirm() async {
    final ok = await _firstPendingCheck(context, [
      _DialogCheck(
        validate: () => _paymentTypeId == null
            ? 'register.requiredField'
                .tr(args: ['forms.serviceOrder.paymentType'.tr()])
            : null,
      ),
      _DialogCheck(
        validate: () => _validateParcels(_parcels.text),
        focusNode: _parcelsFocus,
        fieldKey: _parcelsKey,
      ),
      _DialogCheck(
        validate: () => _validateDtExpiration(_dtExpiration.text),
        focusNode: _dtExpirationFocus,
        fieldKey: _dtExpirationKey,
      ),
    ]);
    if (!ok || !mounted) return;
    Navigator.of(context).pop(ServiceOrderInvoiceInput(
      dtExpiration:  displayDateToIso(_dtExpiration.text)!,
      paymentTypeId: _paymentTypeId!,
      parcels:       int.parse(_parcels.text.trim()),
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
                focusNode: _parcelsFocus,
                fieldKey: _parcelsKey,
                keyboardType: TextInputType.number,
                validator: (value) => _validateParcels(value)?.tr(),
              ),
              const SizedBox(height: 16),
              SetesTextField(
                label: 'forms.serviceOrder.dtExpiration'.tr(),
                hint: 'register.dateHint'.tr(),
                controller: _dtExpiration,
                focusNode: _dtExpirationFocus,
                fieldKey: _dtExpirationKey,
                validator: (value) => _validateDtExpiration(value)?.tr(),
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
