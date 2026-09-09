import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/entity/widgets/entity_date.dart';
import '../../../../shared/feedback/feedback.dart';
import '../../../../shared/format/money.dart';
import '../../../../shared/lookup/datasource/salesman_lookup_datasource.dart';
import '../../../../shared/lookup/entity/role_lookup_entity.dart';
import '../../../../shared/register/register_config_button.dart';
import '../../../../shared/register/register_paging_bar.dart';
import '../../data/datasource/order_datasource.dart';
import '../../domain/entity/order_entity.dart';
import '../bloc/order_bloc.dart';
import '../../../../shared/session/current_interface.dart';
import '../../../../shared/billing/cancel_invoice_dialog.dart';
import 'order_checks_dialog.dart';
import 'order_negotiation_section.dart';

/// Tela de Pedido de Venda — interface 'orders', grupo Vendas. TELA DE
/// PROCESSO (molde service_orders): LISTA em abas Abertos × Faturados
/// (consulta por status na API) com FAB "Novo pedido" (cliente + vendedor
/// opcional); tap na linha abre o DETALHE do pedido — aberto permite
/// itens (incluir/editar/remover via os DOIS lookups, mercadoria×serviço
/// — conjugada é CONSEQUÊNCIA do item incluído, nunca escolha na
/// abertura), NEGOCIAÇÃO (forma + prazo × parcelamento elaborado —
/// seção própria, prompt_negociacao_pedido.md), cancelar e VALIDAR E
/// FATURAR (chama /api/billing/validate e, sem pendências, RELÊ a
/// negociação: parcela em cheque abre o dialog de cheques (D5) antes do
/// /api/billing/invoice); faturado é somente leitura.
class OrderPage extends StatefulWidget {
  const OrderPage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das telas.
  final String title;

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage>
    with SingleTickerProviderStateMixin {
  late final OrderBloc _bloc;
  late final OrderDatasource _datasource;
  late final SalesmanLookupDatasource _salesmanLookup;
  late final TabController _tabs;
  final _filter = TextEditingController();

  static const _statuses = ['A', 'F'];

  /// Aba refletida na tela — evita reload redundante quando o BLoC muda a
  /// aba sozinho (ex.: pós-faturamento cai em Faturados).
  String _status = 'A';

  /// Acesso à seção de negociação para ancorar o `fields[]` do PUT no
  /// campo certo (one-shot OrderNegotiationFailure). Trocada a cada
  /// pedido aberto — estado da seção nunca vaza de um pedido pro outro.
  GlobalKey<OrderNegotiationSectionState> _negotiationKey = GlobalKey();
  int? _negotiationOrderId;

  /// Negociação que dirigiu o ÚLTIMO dialog de cheques — em 422
  /// CHECK_SUM_MISMATCH/CHECK_REQUIRED o dialog reabre sobre as mesmas
  /// parcelas com os cheques digitados.
  OrderNegotiation? _checksNegotiation;

  /// Valor REAL de cada parcela em cheque na nota, apontado pelo `expected`
  /// do CHECK_SUM_MISMATCH (D-N3/D7) — acumula entre reaberturas do dialog
  /// (o servidor aponta uma parcela por vez); zera com a negociação.
  final Map<int, double> _checksExpected = {};

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<OrderBloc>()
      ..add(const OrderListRequested(status: 'A', filter: ''));
    _datasource = Modular.get<OrderDatasource>();
    _salesmanLookup = Modular.get<SalesmanLookupDatasource>();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      final status = _statuses[_tabs.index];
      if (status != _status) {
        _status = status;
        _bloc.add(OrderListRequested(status: status));
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _filter.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------
  // Ações da lista
  // -------------------------------------------------------------------

  /// FAB "Novo pedido": cliente (obrigatório) + vendedor (opcional — a API
  /// resolve o default da carteira; 400 SALESMAN_REQUIRED vira dialog de
  /// validação via one-shot).
  Future<void> _openNewOrder() async {
    final input = await showDialog<_NewOrderInput>(
      context: context,
      builder: (_) => _NewOrderDialog(
        datasource: _datasource,
        salesmanLookup: _salesmanLookup,
      ),
    );
    if (input != null) {
      _bloc.add(OrderOpenRequested(
          customerId: input.customerId, salesmanId: input.salesmanId));
    }
  }

  // -------------------------------------------------------------------
  // Lista (abas Abertos × Faturados)
  // -------------------------------------------------------------------

  Widget _buildList(OrderListState state) {
    _status = state.status;
    final tabIndex = _statuses.indexOf(state.status);
    if (_tabs.index != tabIndex) _tabs.index = tabIndex;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('register.listTitle'.tr(args: [widget.title])),
        actions: [
          const RegisterConfigButton(moduleKey: 'orders'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'forms.order.newOrder'.tr(),
        onPressed: _openNewOrder,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabs,
            tabs: [
              Tab(text: 'forms.order.tabOpen'.tr()),
              Tab(text: 'forms.order.tabInvoiced'.tr()),
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
                  if (state.pageSize != null && state.total != null) ...[
                    const Divider(height: 1),
                    const SizedBox(height: 4),
                    RegisterPagingBar(
                      page: state.page,
                      pageSize: state.pageSize!,
                      total: state.total!,
                      configModuleKey: 'orders',
                      onPageChanged: (page) =>
                          _bloc.add(OrderListRequested(page: page)),
                      onPageSizeChanged: (size) =>
                          _bloc.add(OrderListRequested(pageSize: size)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _search() => _bloc.add(OrderListRequested(filter: _filter.text.trim()));

  Widget _buildListBody(OrderListState state) {
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
          order.salesmanName ?? '',
          'forms.order.itemsCountRow'.tr(args: ['${order.itemsCount}']),
          'forms.order.totalRow'.tr(args: [setesMoney(order.totalValue)]),
        ].where((cell) => cell.isNotEmpty);
        return SetesListTile(
          leading:
              CircleAvatar(child: SetesText('${order.number ?? order.id}')),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: SetesText(order.customerName ?? '')),
              if (order.hasService) ...[
                const SizedBox(width: 8),
                _ConjugatedBadge(context: context),
              ],
            ],
          ),
          subtitle: SetesText(cells.join(' · ')),
          onTap: () => _bloc.add(OrderViewRequested(order.id)),
        );
      },
    );
  }

  // -------------------------------------------------------------------
  // Detalhe do pedido
  // -------------------------------------------------------------------

  Widget _buildDetail(OrderDetailState state) {
    // Pedido diferente do anterior → key nova para a seção (o GlobalKey
    // preservaria a edição local de um pedido dentro do outro).
    if (_negotiationOrderId != state.order.id) {
      _negotiationOrderId = state.order.id;
      _negotiationKey = GlobalKey();
      _checksNegotiation = null;
      _checksExpected.clear();
    }
    return _OrderDetailView(
      key: ValueKey('order-${state.order.id}'),
      title: widget.title,
      state: state,
      datasource: _datasource,
      negotiationKey: _negotiationKey,
      onBack: () => _bloc.add(const OrderBackToListPressed()),
      onCancel: () => _bloc.add(OrderCancelRequested(state.order.id)),
      onItemSave: (itemId, input) => _bloc.add(OrderItemSaveRequested(
          orderId: state.order.id, itemId: itemId, input: input)),
      onItemRemove: (itemId) => _bloc.add(OrderItemRemoveRequested(
          orderId: state.order.id, itemId: itemId)),
      onNegotiationSave: (input) => _bloc.add(OrderNegotiationSaveRequested(
          orderId: state.order.id, input: input)),
      onNegotiationReload: () =>
          _bloc.add(OrderNegotiationRequested(state.order.id)),
      onValidate: () =>
          _bloc.add(OrderBillingValidateRequested(state.order.id)),
      onReturn: () => _bloc.add(OrderReturnRequested(state.order.id)),
      onCancelInvoice: () => _askCancelInvoice(state.order),
    );
  }

  /// "Cancelar nota" (prompt_cancelamento_nota.md D13/D14): confirmação +
  /// motivo obrigatório no dialog, depois o bloc chama a API.
  Future<void> _askCancelInvoice(OrderFull order) async {
    final reason = await showCancelInvoiceDialog(
        context, order.number?.toString() ?? '${order.id}');
    if (reason == null || !mounted) return;
    _bloc.add(OrderInvoiceCancelRequested(orderId: order.id, reason: reason));
  }

  /// 409 INVOICE_CANCEL_BLOCKED (Q-P4): um código, fields[] tipado com o que
  /// resolver antes — a tela lista; demais falhas seguem a ponte padrão.
  void _onInvoiceCancelFailure(OrderInvoiceCancelFailure state) {
    final failure = state.failure;
    if (failure.code == 'INVOICE_CANCEL_BLOCKED' && failure.fields.isNotEmpty) {
      final lines = failure.fields.map((f) => '• ${f.message}').join('\n');
      showValidationFeedback(
          context, '${'forms.order.cancelInvoiceBlocked'.tr()}\n$lines');
      return;
    }
    _showFailure(failure);
  }

  // -------------------------------------------------------------------
  // Faturamento: validate → (cheques?) → invoice
  // -------------------------------------------------------------------

  /// Validação sem pendências: com forma definida e alguma parcela em
  /// CHEQUE (grade elaborada ou gerada — a negociação foi RELIDA pelo
  /// bloc), coleta os cheques antes do invoice (D5); sem parcela em
  /// cheque, o fluxo original (invoice direto) não muda.
  Future<void> _startInvoice(int orderId, OrderNegotiation? negotiation) async {
    if (negotiation != null && negotiation.billing == null) {
      // Sem forma de pagamento o invoice cairia em 422 ORDER_NO_BILLING —
      // a pendência é da negociação, então a mensagem aponta pra ela.
      await showValidationFeedback(
          context, 'forms.order.negotiationRequired'.tr());
      return;
    }
    if (negotiation != null && negotiation.hasCheckParcel) {
      return _collectChecksAndInvoice(orderId, negotiation);
    }
    _bloc.add(OrderBillingInvoiceRequested(orderId));
  }

  Future<void> _collectChecksAndInvoice(
    int orderId,
    OrderNegotiation negotiation, {
    List<OrderParcelChecksInput> initial = const [],
    String? hint,
  }) async {
    _checksNegotiation = negotiation;
    final checks = await showOrderChecksDialog(
      context,
      parcels: negotiation.effectiveParcels.where((p) => p.isCheck).toList(),
      datasource: _datasource,
      initial: initial,
      expectedAmounts: Map.of(_checksExpected),
      hint: hint,
    );
    if (checks == null || !mounted) return;
    _bloc.add(OrderBillingInvoiceRequested(orderId, checks: checks));
  }

  /// Falha do invoice: 422 de cheque (soma/obrigatório) mostra a mensagem
  /// da API e REABRE o dialog com os cheques digitados, agora com o valor
  /// REAL da parcela na nota (`expected` — a 1ª parcela pode absorver a
  /// diferença de impostos, D7/D-N3); 422 da negociação (base nova,
  /// limite, prazo) ancora na seção, que consome o `expected` como no
  /// PUT; o resto segue a ponte.
  Future<void> _onInvoiceFailure(OrderBillingInvoiceFailure state) async {
    final failure = state.failure;
    final negotiation = _checksNegotiation;
    final isCheckIssue =
        failure.code == 'CHECK_SUM_MISMATCH' || failure.code == 'CHECK_REQUIRED';
    if (negotiation == null || !isCheckIssue) {
      final section = _negotiationKey.currentState;
      if (section != null && failure.fields.isNotEmpty) {
        return section.showServerFailure(failure);
      }
      return _showFailure(failure);
    }
    for (final field in failure.fields) {
      final expected = field.expected;
      final parcel = int.tryParse(field.field.split('.').last);
      if (expected != null && field.field.startsWith('checks.') && parcel != null) {
        _checksExpected[parcel] = expected;
      }
    }

    final message = failure.fields.isNotEmpty
        ? failure.fields.first.message.tr()
        : failure.message.tr();
    await showValidationFeedback(context, message);
    if (!mounted) return;
    await _collectChecksAndInvoice(
      negotiation.orderId,
      negotiation,
      initial: state.checks,
      hint: message,
    );
  }

  /// Falha genérica (Framework de Mensagens): fields[] presente = dialog de
  /// validação com a mensagem do campo; senão a ponte deriva o canal.
  Future<void> _showFailure(Failure failure) {
    if (failure.fields.isNotEmpty) {
      return showValidationFeedback(context, failure.fields.first.message.tr());
    }
    return showFailureFeedback(context, failure);
  }

  /// Dialog INFORMATIVO de pendências (issues do /billing/validate) — a
  /// mensagem de cada issue já vem PRONTA da API.
  Future<void> _showIssuesDialog(List<OrderBillingIssue> issues) => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: SetesText('forms.order.billingIssuesTitle'.tr()),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final issue in issues)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SetesText('• ${issue.message}'),
                    ),
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

  @override
  Widget build(BuildContext context) => BlocConsumer<OrderBloc, OrderState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is OrderActionSuccess ||
            current is OrderActionFailure ||
            current is OrderBillingValidated ||
            current is OrderBillingInvoiced ||
            current is OrderBillingInvoiceFailure ||
            current is OrderNegotiationFailure ||
            current is OrderReturnOpened ||
            current is OrderInvoiceCancelled ||
            current is OrderInvoiceCancelFailure,
        // PONTE de feedback (Framework de Mensagens): a tela nunca chama
        // ScaffoldMessenger/AlertDialog para desfecho — sucesso = SnackBar
        // via ponte; falha = dialog (SALESMAN_REQUIRED, ORDER_INVOICED
        // viram validação com a mensagem da API); validação SEM issues
        // segue para o faturamento (cheques antes, se houver parcela em
        // cheque — D5); validação COM issues abre o dialog de pendências
        // e NÃO fatura; falha da negociação é ancorada no campo pela
        // própria seção.
        listener: (context, state) {
          if (state is OrderBillingValidated) {
            if (state.result.canInvoice) {
              _startInvoice(state.result.orderId, state.negotiation);
            } else {
              _showIssuesDialog(state.result.issues);
            }
            return;
          }
          if (state is OrderBillingInvoiced) {
            _checksNegotiation = null;
            _checksExpected.clear();
            showSuccessFeedback(context, 'forms.order.invoiceGenerated',
                args: [state.result.invoiceNumber]);
            return;
          }
          if (state is OrderBillingInvoiceFailure) {
            _onInvoiceFailure(state);
            return;
          }
          if (state is OrderNegotiationFailure) {
            final section = _negotiationKey.currentState;
            if (section != null) {
              section.showServerFailure(state.failure);
            } else {
              _showFailure(state.failure);
            }
            return;
          }
          if (state is OrderInvoiceCancelled) {
            showSuccessFeedback(context, 'forms.order.invoiceCancelled',
                args: [state.result.invoiceNumber]);
            return;
          }
          if (state is OrderInvoiceCancelFailure) {
            _onInvoiceCancelFailure(state);
            return;
          }
          if (state is OrderReturnOpened) {
            // A condução da devolução é do módulo order_returns — a
            // recém-criada aparece no topo da aba Abertas de lá.
            Modular.to.navigate('/home/order-returns/');
            return;
          }
          if (state is OrderActionSuccess) {
            showSuccessFeedback(context, state.messageKey,
                args: state.args.isEmpty ? null : state.args);
            return;
          }
          _showFailure((state as OrderActionFailure).failure);
        },
        buildWhen: (_, current) =>
            current is OrderListState || current is OrderDetailState,
        builder: (context, state) => switch (state) {
          OrderDetailState() => _buildDetail(state),
          OrderListState() => _buildList(state),
          _ => _buildList(const OrderListState(loading: true)),
        },
      );
}

/// Quantidade sem zeros à direita ('2' / '1,5') — pt-BR usa vírgula.
String _quantityText(double quantity) => quantity == quantity.roundToDouble()
    ? '${quantity.toInt()}'
    : quantity.toString().replaceAll('.', ',');

/// Selo visual de pedido CONJUGADO (mercadoria + serviço) na lista.
class _ConjugatedBadge extends StatelessWidget {
  const _ConjugatedBadge({required this.context});
  final BuildContext context;

  @override
  Widget build(BuildContext _) {
    final theme = Theme.of(context);
    return Tooltip(
      message: 'forms.order.conjugated'.tr(),
      child: Icon(Icons.build_circle_outlined,
          size: 18, color: theme.colorScheme.secondary),
    );
  }
}

/// Checagem de UM campo de dialog de ação: [validate] devolve a chave i18n
/// (ou texto pronto) da pendência; [focusNode]/[fieldKey] ancoram o retorno
/// do foco e a marca inline SÓ nele.
class _DialogCheck {
  const _DialogCheck({required this.validate, this.focusNode, this.fieldKey});

  final String? Function() validate;
  final FocusNode? focusNode;
  final GlobalKey<FormFieldState<String>>? fieldKey;
}

/// UMA pendência por vez nos dialogs de ação: percorre as checagens na
/// ordem declarada e, na PRIMEIRA mensagem, mostra o dialog da ponte → OK
/// → marca só o campo pendente e devolve o foco a ele. true = tudo passou.
Future<bool> _firstPendingCheck(
    BuildContext context, List<_DialogCheck> checks) async {
  for (final check in checks) {
    final message = check.validate();
    if (message != null) {
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

/// Detalhe do pedido: cabeçalho (cliente/vendedor/nº/data/status/total),
/// itens (com indicador visual mercadoria×serviço), seção NEGOCIAÇÃO
/// (forma + prazo × parcelas — entre os itens e a ação terminal) e — no
/// ABERTO — ações de item, Cancelar (delete_outline na AppBar) e o botão
/// primário Validar e Faturar. FATURADO é somente leitura.
class _OrderDetailView extends StatelessWidget {
  const _OrderDetailView({
    required this.title,
    required this.state,
    required this.datasource,
    required this.negotiationKey,
    required this.onBack,
    required this.onCancel,
    required this.onItemSave,
    required this.onItemRemove,
    required this.onNegotiationSave,
    required this.onNegotiationReload,
    required this.onValidate,
    required this.onReturn,
    required this.onCancelInvoice,
    super.key,
  });

  final String title;
  final OrderDetailState state;
  final OrderDatasource datasource;

  /// Key da seção de negociação (a página ancora o fields[] por ela).
  final GlobalKey<OrderNegotiationSectionState> negotiationKey;
  final VoidCallback onBack;
  final VoidCallback onCancel;
  final void Function(int? itemId, OrderItemInput input) onItemSave;
  final void Function(int itemId) onItemRemove;
  final void Function(OrderNegotiationInput input) onNegotiationSave;
  final VoidCallback onNegotiationReload;
  final VoidCallback onValidate;

  /// Ação "Devolver" do pedido FATURADO — abre a devolução de mercadoria.
  final VoidCallback onReturn;

  /// Ação "Cancelar nota" do pedido FATURADO (privilégio CANCELAR — D12).
  final VoidCallback onCancelInvoice;

  OrderFull get order => state.order;
  bool get busy => state.saving;

  /// Cancelamento confirmado via decisão TIPADA da ponte: Sim = cancelar;
  /// Cancelar (ou fechar) = nada.
  Future<void> _confirmCancel(BuildContext context) async {
    final decision = await askDecision(
      context,
      message: 'forms.order.confirmCancel'.tr(),
      yesLabel: 'forms.order.cancelOrder'.tr(),
    );
    if (decision == SetesDecision.yes) onCancel();
  }

  Future<void> _openItemDialog(BuildContext context,
      {OrderItem? existing}) async {
    final input = await showDialog<OrderItemInput>(
      context: context,
      builder: (_) => _OrderItemDialog(datasource: datasource, existing: existing),
    );
    if (input != null) onItemSave(existing?.id, input);
  }

  /// Remoção de item confirmada via decisão TIPADA da ponte.
  Future<void> _confirmRemoveItem(BuildContext context, OrderItem item) async {
    final decision = await askDecision(
      context,
      message: 'register.confirmDelete'.tr(),
      yesLabel: 'register.delete'.tr(),
    );
    if (decision == SetesDecision.yes) onItemRemove(item.id);
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
          Row(
            children: [
              Flexible(
                child: SetesText(
                  order.customerName ?? '',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (order.hasService) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: 'forms.order.conjugated'.tr(),
                  child: Icon(Icons.build_circle_outlined,
                      size: 20, color: theme.colorScheme.secondary),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          _headerRow(
              'forms.order.numberRow'.tr(args: ['${order.number ?? order.id}'])),
          _headerRow(
              'forms.order.dateRow'.tr(args: [isoDateToDisplay(order.dtRecord)])),
          _headerRow('forms.order.salesmanRow'.tr(args: [order.salesmanName ?? ''])),
          _headerRow(order.isOpen
              ? 'forms.order.statusOpen'.tr()
              : 'forms.order.statusInvoiced'.tr()),
          const SizedBox(height: 8),
          // Total em destaque — recalculado no servidor a cada operação.
          SetesText(
            'forms.order.totalRow'.tr(args: [setesMoney(order.totalValue)]),
            style:
                theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(BuildContext context, OrderItem item) {
    final theme = Theme.of(context);
    final discount = item.discountValue;
    final subtitle = discount > 0
        ? 'forms.order.itemRowDiscount'.tr(args: [
            _quantityText(item.quantity),
            setesMoney(item.unitValue),
            setesMoney(discount),
            setesMoney(item.total),
          ])
        : 'forms.order.itemRow'.tr(args: [
            _quantityText(item.quantity),
            setesMoney(item.unitValue),
            setesMoney(item.total),
          ]);
    return SetesListTile(
      leading: Icon(
        item.isService ? Icons.build_circle_outlined : Icons.inventory_2_outlined,
        color: theme.colorScheme.secondary,
      ),
      title: SetesText(item.productDescription ?? ''),
      subtitle: SetesText(subtitle),
      trailing: order.isOpen
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'forms.order.editItem'.tr(),
                  onPressed:
                      busy ? null : () => _openItemDialog(context, existing: item),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'forms.order.removeItem'.tr(),
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
                tooltip: 'forms.order.cancelOrder'.tr(),
                onPressed: busy ? null : () => _confirmCancel(context),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            SetesText.title('forms.order.items'.tr()),
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
                label: 'forms.order.addItem'.tr(),
                icon: Icons.add,
                onPressed: busy ? null : () => _openItemDialog(context),
              ),
            ],
            // NEGOCIAÇÃO — entre os itens e a ação terminal (aberto =
            // editável; faturado = somente leitura).
            const SizedBox(height: 24),
            SetesText.title('forms.order.negotiation'.tr()),
            const SizedBox(height: 8),
            OrderNegotiationSection(
              key: negotiationKey,
              negotiation: state.negotiation,
              datasource: datasource,
              busy: busy,
              onSave: onNegotiationSave,
              onReload: onNegotiationReload,
            ),
            if (order.isOpen) ...[
              const SizedBox(height: 24),
              // Botão primário do processo: validate → (cheques) → invoice.
              SetesButton(
                label: 'forms.order.validateAndInvoice'.tr(),
                icon: Icons.receipt_long_outlined,
                onPressed: busy ? null : onValidate,
              ),
            ] else ...[
              const SizedBox(height: 24),
              // Pedido FATURADO: abre a devolução de mercadoria (ajuste de
              // Entrada ancorado neste pedido — módulo order_returns).
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  SetesButton(
                    label: 'forms.order.openReturn'.tr(),
                    icon: Icons.assignment_return_outlined,
                    onPressed: busy ? null : onReturn,
                  ),
                  // Cancelamento da nota (Onda 1 — nota não transmitida):
                  // só com o privilégio CANCELAR da interface (D12); a API
                  // aplica de novo na rota.
                  if (CurrentInterface.can('CANCELAR'))
                    SetesButton(
                      label: 'forms.order.cancelInvoice'.tr(),
                      icon: Icons.cancel_outlined,
                      kind: SetesButtonKind.secondary,
                      onPressed: busy ? null : onCancelInvoice,
                    ),
                ],
              ),
            ],
          ],
        ),
      );
}

/// Origem do lookup escolhida pelo usuário no seletor — só define QUAL
/// lookup a busca chama; o campo enviado ao salvar é sempre productId (o
/// backend decide mercadoria×serviço pelo kind do produto).
enum _ItemBranch { merchandise, service }

/// Dialog de item do pedido: seletor de item com DOIS caminhos de busca
/// (toggle Mercadoria × Serviço apontando pros dois lookups) + quantidade
/// (>0, default 1) + valor unitário SEMPRE DIGITADO (>=0) + desconto
/// (>=0, opcional). Devolve o [OrderItemInput] via Navigator.pop.
class _OrderItemDialog extends StatefulWidget {
  const _OrderItemDialog({required this.datasource, this.existing});

  final OrderDatasource datasource;
  final OrderItem? existing;

  @override
  State<_OrderItemDialog> createState() => _OrderItemDialogState();
}

class _OrderItemDialogState extends State<_OrderItemDialog> {
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
  _ItemBranch _branch = _ItemBranch.merchandise;

  bool get _editing => widget.existing != null;

  static String _decimalText(double value) =>
      value.toStringAsFixed(2).replaceAll('.', ',');

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _productId          = existing?.productId;
    _productDescription = existing?.productDescription ?? '';
    _branch = existing != null && existing.isService
        ? _ItemBranch.service
        : _ItemBranch.merchandise;
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
    final onSearch = _branch == _ItemBranch.merchandise
        ? widget.datasource.merchandiseLookup
        : widget.datasource.serviceLookup;
    final picked = await showSetesLookup<OrderProductLookup>(
      context: context,
      title: 'lookup.products'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: onSearch,
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

  /// Troca o caminho de busca — limpa a escolha anterior (o item não fica
  /// "meio mercadoria, meio serviço").
  void _setBranch(_ItemBranch branch) {
    if (branch == _branch) return;
    setState(() {
      _branch = branch;
      _productId = null;
      _productDescription = '';
    });
  }

  double? _parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  String? _validateQuantity(String? value) {
    final quantity = _parse(value ?? '');
    return (quantity == null || quantity <= 0)
        ? 'forms.order.quantityInvalid'
        : null;
  }

  String? _validateUnitValue(String? value) {
    final unitValue = _parse(value ?? '');
    return (unitValue == null || unitValue < 0)
        ? 'forms.order.unitValueInvalid'
        : null;
  }

  /// Desconto é OPCIONAL — válido SE preenchido.
  String? _validateDiscount(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final discount = _parse(value);
    return (discount == null || discount < 0)
        ? 'forms.order.discountInvalid'
        : null;
  }

  /// Valida via ponte: UMA pendência por vez, na ORDEM dos campos, com
  /// foco no pendente (o lookup de produto não recebe foco/marca).
  Future<void> _confirm() async {
    final ok = await _firstPendingCheck(context, [
      _DialogCheck(
        validate: () => _productId == null
            ? 'register.requiredField'.tr(args: ['forms.order.product'.tr()])
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
    Navigator.of(context).pop(OrderItemInput(
      productId:     _productId!,
      quantity:      _parse(_quantity.text)!,
      unitValue:     _parse(_unitValue.text)!,
      discountValue: _discountValue.text.trim().isEmpty
          ? null
          : _parse(_discountValue.text),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: SetesText(
          _editing ? 'forms.order.editItem'.tr() : 'forms.order.addItem'.tr()),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Toggle Mercadoria × Serviço — só decide QUAL lookup abre; o
            // backend decide o ramo sozinho pelo kind do produto.
            SegmentedButton<_ItemBranch>(
              segments: [
                ButtonSegment(
                  value: _ItemBranch.merchandise,
                  label: Text('forms.order.merchandise'.tr()),
                  icon: const Icon(Icons.inventory_2_outlined),
                ),
                ButtonSegment(
                  value: _ItemBranch.service,
                  label: Text('forms.order.service'.tr()),
                  icon: const Icon(Icons.build_circle_outlined),
                ),
              ],
              selected: {_branch},
              onSelectionChanged: (selection) => _setBranch(selection.first),
              style: SegmentedButton.styleFrom(
                selectedForegroundColor: theme.colorScheme.onSecondaryContainer,
                selectedBackgroundColor: theme.colorScheme.secondaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            SetesLookupField(
              label: 'forms.order.product'.tr(),
              display: _productDescription,
              onSearch: _pickProduct,
            ),
            const SizedBox(height: 16),
            SetesTextField(
              label: 'forms.order.quantity'.tr(),
              controller: _quantity,
              focusNode: _quantityFocus,
              fieldKey: _quantityKey,
              autofocus: _editing,
              keyboardType: TextInputType.number,
              validator: (value) => _validateQuantity(value)?.tr(),
            ),
            const SizedBox(height: 16),
            SetesTextField(
              label: 'forms.order.unitValue'.tr(),
              controller: _unitValue,
              focusNode: _unitValueFocus,
              fieldKey: _unitValueKey,
              keyboardType: TextInputType.number,
              validator: (value) => _validateUnitValue(value)?.tr(),
            ),
            const SizedBox(height: 16),
            SetesTextField(
              label: 'forms.order.discountValue'.tr(),
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
}

/// Resultado do dialog de novo pedido.
class _NewOrderInput {
  const _NewOrderInput({required this.customerId, this.salesmanId});
  final int customerId;
  final int? salesmanId;
}

/// Dialog do FAB "Novo pedido": cliente (obrigatório, lookup) + vendedor
/// (opcional, lookup com onClear — a API resolve o default da carteira do
/// cliente se ficar vazio; 400 SALESMAN_REQUIRED se nenhum existir).
class _NewOrderDialog extends StatefulWidget {
  const _NewOrderDialog({required this.datasource, required this.salesmanLookup});

  final OrderDatasource datasource;
  final SalesmanLookupDatasource salesmanLookup;

  @override
  State<_NewOrderDialog> createState() => _NewOrderDialogState();
}

class _NewOrderDialogState extends State<_NewOrderDialog> {
  int? _customerId;
  String _customerDisplay = '';
  int? _salesmanId;
  String _salesmanDisplay = '';

  Future<void> _pickCustomer() async {
    final picked = await showSetesLookup<OrderCustomerLookup>(
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
        _customerId      = picked.id;
        _customerDisplay = picked.display;
      });
    }
  }

  Future<void> _pickSalesman() async {
    final picked = await showSetesLookup<RoleLookup>(
      context: context,
      title: 'lookup.salesmen'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: widget.salesmanLookup.list,
      itemId: (s) => s.id,
      itemLabel: (s) => s.name ?? '',
    );
    if (picked != null) {
      setState(() {
        _salesmanId      = picked.id;
        _salesmanDisplay = picked.name ?? '';
      });
    }
  }

  /// Valida via ponte: só o cliente é obrigatório — o vendedor é opcional
  /// (a API decide/exige via SALESMAN_REQUIRED).
  Future<void> _confirm() async {
    final ok = await _firstPendingCheck(context, [
      _DialogCheck(
        validate: () => _customerId == null
            ? 'register.requiredField'.tr(args: ['forms.order.customer'.tr()])
            : null,
      ),
    ]);
    if (!ok || !mounted) return;
    Navigator.of(context)
        .pop(_NewOrderInput(customerId: _customerId!, salesmanId: _salesmanId));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: SetesText('forms.order.newOrder'.tr()),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SetesLookupField(
                label: 'forms.order.customer'.tr(),
                display: _customerDisplay,
                onSearch: _pickCustomer,
              ),
              const SizedBox(height: 16),
              SetesLookupField(
                label: 'forms.order.salesman'.tr(),
                display: _salesmanDisplay,
                onSearch: _pickSalesman,
                onClear: () => setState(() {
                  _salesmanId      = null;
                  _salesmanDisplay = '';
                }),
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
