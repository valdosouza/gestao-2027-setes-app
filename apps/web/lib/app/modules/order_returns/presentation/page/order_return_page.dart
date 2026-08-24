import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:setes_widgets/setes_widgets.dart';

import '../../../../shared/entity/widgets/entity_date.dart';
import '../../../../shared/feedback/feedback.dart';
import '../../../../shared/format/money.dart';
import '../../../../shared/register/register_config_button.dart';
import '../../../../shared/register/register_paging_bar.dart';
import '../../data/datasource/order_return_datasource.dart';
import '../../domain/entity/order_return_entity.dart';
import '../bloc/order_return_bloc.dart';

/// Tela de Devolução de Mercadoria — interface 'order-returns', grupo
/// Vendas. TELA DE PROCESSO (molde orders): LISTA em abas Abertas ×
/// Faturadas (consulta por status na API) com filtro por cliente — SEM
/// FAB: a devolução NASCE no pedido de venda faturado (ação "Devolver" do
/// módulo orders). Tap na linha abre o DETALHE — aberta permite editar a
/// QUANTIDADE de cada item (teto maxQuantity), remover item (sem
/// re-inclusão — removeu errado → cancela e reabre), cancelar e VALIDAR E
/// FATURAR (dialog pede o CFOP → /api/billing/validate com adjustment
/// { cfopId } e, sem pendências, /api/billing/invoice); faturada é
/// somente leitura.
class OrderReturnPage extends StatefulWidget {
  const OrderReturnPage({required this.title, super.key});

  /// Nome da interface no menu (trCatalog) — título das telas.
  final String title;

  @override
  State<OrderReturnPage> createState() => _OrderReturnPageState();
}

class _OrderReturnPageState extends State<OrderReturnPage>
    with SingleTickerProviderStateMixin {
  late final OrderReturnBloc _bloc;
  late final OrderReturnDatasource _datasource;
  late final TabController _tabs;
  final _filter = TextEditingController();

  static const _statuses = ['A', 'F'];

  /// Aba refletida na tela — evita reload redundante quando o BLoC muda a
  /// aba sozinho (ex.: pós-faturamento cai em Faturadas).
  String _status = 'A';

  @override
  void initState() {
    super.initState();
    _bloc = Modular.get<OrderReturnBloc>()
      ..add(const OrderReturnListRequested(status: 'A', filter: ''));
    _datasource = Modular.get<OrderReturnDatasource>();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      final status = _statuses[_tabs.index];
      if (status != _status) {
        _status = status;
        _bloc.add(OrderReturnListRequested(status: status));
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
  // Lista (abas Abertas × Faturadas)
  // -------------------------------------------------------------------

  Widget _buildList(OrderReturnListState state) {
    _status = state.status;
    final tabIndex = _statuses.indexOf(state.status);
    if (_tabs.index != tabIndex) _tabs.index = tabIndex;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('register.listTitle'.tr(args: [widget.title])),
        actions: [
          const RegisterConfigButton(moduleKey: 'order-returns'),
        ],
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabs,
            tabs: [
              Tab(text: 'forms.orderReturn.tabOpen'.tr()),
              Tab(text: 'forms.orderReturn.tabInvoiced'.tr()),
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
                      configModuleKey: 'order-returns',
                      onPageChanged: (page) =>
                          _bloc.add(OrderReturnListRequested(page: page)),
                      onPageSizeChanged: (size) =>
                          _bloc.add(OrderReturnListRequested(pageSize: size)),
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

  void _search() =>
      _bloc.add(OrderReturnListRequested(filter: _filter.text.trim()));

  Widget _buildListBody(OrderReturnListState state) {
    if (state.loading) return const SetesCircularProgressIndicator();
    if (state.items.isEmpty) {
      return Center(child: SetesText('register.emptyList'.tr()));
    }
    return ListView.separated(
      itemCount: state.items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final orderReturn = state.items[index];
        final cells = [
          'forms.orderReturn.originRow'.tr(args: [orderReturn.originDisplay]),
          isoDateToDisplay(orderReturn.dtRecord),
          'forms.orderReturn.itemsCountRow'
              .tr(args: ['${orderReturn.itemsCount}']),
          'forms.orderReturn.totalRow'
              .tr(args: [setesMoney(orderReturn.totalValue)]),
          orderReturn.status == 'A'
              ? 'forms.orderReturn.tabOpenSingular'.tr()
              : 'forms.orderReturn.tabInvoicedSingular'.tr(),
        ].where((cell) => cell.isNotEmpty);
        return SetesListTile(
          leading: CircleAvatar(
              child: SetesText('${orderReturn.number ?? orderReturn.id}')),
          title: SetesText(orderReturn.customerName ?? ''),
          subtitle: SetesText(cells.join(' · ')),
          onTap: () => _bloc.add(OrderReturnViewRequested(orderReturn.id)),
        );
      },
    );
  }

  // -------------------------------------------------------------------
  // Detalhe da devolução
  // -------------------------------------------------------------------

  Widget _buildDetail(OrderReturnDetailState state) => _OrderReturnDetailView(
        key: ValueKey('order-return-${state.orderReturn.id}'),
        title: widget.title,
        state: state,
        datasource: _datasource,
        onBack: () => _bloc.add(const OrderReturnBackToListPressed()),
        onCancel: () =>
            _bloc.add(OrderReturnCancelRequested(state.orderReturn.id)),
        onItemQuantity: (itemId, quantity) =>
            _bloc.add(OrderReturnItemQuantityRequested(
                returnId: state.orderReturn.id,
                itemId: itemId,
                quantity: quantity)),
        onItemRemove: (itemId) => _bloc.add(OrderReturnItemRemoveRequested(
            returnId: state.orderReturn.id, itemId: itemId)),
        onValidate: (cfopId) => _bloc.add(OrderReturnBillingValidateRequested(
            returnId: state.orderReturn.id, cfopId: cfopId)),
      );

  /// Dialog INFORMATIVO de pendências (issues do /billing/validate) — a
  /// mensagem de cada issue já vem PRONTA da API.
  Future<void> _showIssuesDialog(List<OrderReturnBillingIssue> issues) =>
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: SetesText('forms.orderReturn.billingIssuesTitle'.tr()),
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
  Widget build(BuildContext context) =>
      BlocConsumer<OrderReturnBloc, OrderReturnState>(
        bloc: _bloc,
        listenWhen: (_, current) =>
            current is OrderReturnActionSuccess ||
            current is OrderReturnActionFailure ||
            current is OrderReturnBillingValidated ||
            current is OrderReturnBillingInvoiced,
        // PONTE de feedback (Framework de Mensagens): a tela nunca chama
        // ScaffoldMessenger/AlertDialog para desfecho — sucesso = SnackBar
        // via ponte; falha = dialog (RETURN_INVALID, ORDER_INVOICED viram
        // validação com a mensagem da API); validação SEM issues dispara o
        // invoice em cadeia (mesmo CFOP); validação COM issues abre o
        // dialog de pendências e NÃO fatura.
        listener: (context, state) {
          if (state is OrderReturnBillingValidated) {
            if (state.result.canInvoice) {
              _bloc.add(OrderReturnBillingInvoiceRequested(
                  returnId: state.result.orderId, cfopId: state.cfopId));
            } else {
              _showIssuesDialog(state.result.issues);
            }
            return;
          }
          if (state is OrderReturnBillingInvoiced) {
            showSuccessFeedback(context, 'forms.orderReturn.invoiceGenerated',
                args: [state.result.invoiceNumber]);
            return;
          }
          if (state is OrderReturnActionSuccess) {
            showSuccessFeedback(context, state.messageKey,
                args: state.args.isEmpty ? null : state.args);
            return;
          }
          final failure = (state as OrderReturnActionFailure).failure;
          if (failure.fields.isNotEmpty) {
            showValidationFeedback(context, failure.fields.first.message.tr());
          } else {
            showFailureFeedback(context, failure);
          }
        },
        buildWhen: (_, current) =>
            current is OrderReturnListState ||
            current is OrderReturnDetailState,
        builder: (context, state) => switch (state) {
          OrderReturnDetailState() => _buildDetail(state),
          OrderReturnListState() => _buildList(state),
          _ => _buildList(const OrderReturnListState(loading: true)),
        },
      );
}

/// Quantidade sem zeros à direita ('2' / '1,5') — pt-BR usa vírgula.
String _quantityText(double quantity) => quantity == quantity.roundToDouble()
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

/// Detalhe da devolução: cabeçalho (cliente/nº/pedido de origem/data/
/// status/total), itens pré-carregados (quantidade × valor unitário =
/// total) e — na ABERTA — editar quantidade (teto maxQuantity), remover
/// item (sem re-inclusão), Cancelar (delete_outline na AppBar) e o botão
/// primário Validar e Faturar (dialog do CFOP). FATURADA é somente
/// leitura.
class _OrderReturnDetailView extends StatelessWidget {
  const _OrderReturnDetailView({
    required this.title,
    required this.state,
    required this.datasource,
    required this.onBack,
    required this.onCancel,
    required this.onItemQuantity,
    required this.onItemRemove,
    required this.onValidate,
    super.key,
  });

  final String title;
  final OrderReturnDetailState state;
  final OrderReturnDatasource datasource;
  final VoidCallback onBack;
  final VoidCallback onCancel;
  final void Function(int itemId, double quantity) onItemQuantity;
  final void Function(int itemId) onItemRemove;
  final void Function(String cfopId) onValidate;

  OrderReturnFull get orderReturn => state.orderReturn;
  bool get busy => state.saving;

  /// Cancelamento confirmado via decisão TIPADA da ponte: Sim = cancelar;
  /// Cancelar (ou fechar) = nada.
  Future<void> _confirmCancel(BuildContext context) async {
    final decision = await askDecision(
      context,
      message: 'forms.orderReturn.confirmCancel'.tr(),
      yesLabel: 'forms.orderReturn.cancelReturn'.tr(),
    );
    if (decision == SetesDecision.yes) onCancel();
  }

  Future<void> _openQuantityDialog(
      BuildContext context, OrderReturnItem item) async {
    final quantity = await showDialog<double>(
      context: context,
      builder: (_) => _ReturnQuantityDialog(item: item),
    );
    if (quantity != null) onItemQuantity(item.id, quantity);
  }

  /// Remoção de item confirmada via decisão TIPADA da ponte — a mensagem
  /// avisa que NÃO existe re-inclusão (removeu errado → cancela e reabre).
  Future<void> _confirmRemoveItem(
      BuildContext context, OrderReturnItem item) async {
    final decision = await askDecision(
      context,
      message: 'forms.orderReturn.confirmRemoveItem'.tr(),
      yesLabel: 'forms.orderReturn.removeItem'.tr(),
    );
    if (decision == SetesDecision.yes) onItemRemove(item.id);
  }

  /// Botão primário: dialog do CFOP (obrigatório, lookup) → dispara o
  /// validate com adjustment = { cfopId }.
  Future<void> _openInvoiceDialog(BuildContext context) async {
    final cfopId = await showDialog<String>(
      context: context,
      builder: (_) => _ReturnInvoiceDialog(datasource: datasource),
    );
    if (cfopId != null) onValidate(cfopId);
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
            orderReturn.customerName ?? '',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _headerRow('forms.orderReturn.numberRow'
              .tr(args: ['${orderReturn.number ?? orderReturn.id}'])),
          _headerRow('forms.orderReturn.originRow'
              .tr(args: [orderReturn.originDisplay])),
          _headerRow('forms.orderReturn.dateRow'
              .tr(args: [isoDateToDisplay(orderReturn.dtRecord)])),
          _headerRow(orderReturn.isOpen
              ? 'forms.orderReturn.statusOpen'.tr()
              : 'forms.orderReturn.statusInvoiced'.tr()),
          const SizedBox(height: 8),
          // Total em destaque — recalculado no servidor a cada operação.
          SetesText(
            'forms.orderReturn.totalRow'
                .tr(args: [setesMoney(orderReturn.totalValue)]),
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(BuildContext context, OrderReturnItem item) {
    final theme = Theme.of(context);
    final subtitle = 'forms.orderReturn.itemRow'.tr(args: [
      _quantityText(item.quantity),
      setesMoney(item.unitValue),
      setesMoney(item.total),
    ]);
    return SetesListTile(
      leading: Icon(Icons.assignment_return_outlined,
          color: theme.colorScheme.secondary),
      title: SetesText(item.productDescription ?? ''),
      subtitle: SetesText(subtitle),
      trailing: orderReturn.isOpen
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'forms.orderReturn.editItem'.tr(),
                  onPressed: busy
                      ? null
                      : () => _openQuantityDialog(context, item),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'forms.orderReturn.removeItem'.tr(),
                  onPressed:
                      busy ? null : () => _confirmRemoveItem(context, item),
                ),
              ],
            )
          : null,
      onTap: orderReturn.isOpen && !busy
          ? () => _openQuantityDialog(context, item)
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
            if (orderReturn.isOpen)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'forms.orderReturn.cancelReturn'.tr(),
                onPressed: busy ? null : () => _confirmCancel(context),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            SetesText.title('forms.orderReturn.items'.tr()),
            const SizedBox(height: 8),
            if (orderReturn.items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SetesText('register.emptyList'.tr()),
              )
            else
              for (final item in orderReturn.items) ...[
                _buildItemTile(context, item),
                const Divider(height: 1),
              ],
            if (orderReturn.isOpen) ...[
              const SizedBox(height: 24),
              // Botão primário do processo: dialog do CFOP → validate →
              // invoice em cadeia.
              SetesButton(
                label: 'forms.orderReturn.validateAndInvoice'.tr(),
                icon: Icons.receipt_long_outlined,
                onPressed: busy ? null : () => _openInvoiceDialog(context),
              ),
            ],
          ],
        ),
      );
}

/// Dialog de quantidade do item da devolução — ÚNICO campo editável:
/// quantidade > 0 com TETO no saldo devolvível ([OrderReturnItem.maxQuantity],
/// mensagem do limite no hint e na pendência). Devolve a quantidade via
/// Navigator.pop.
class _ReturnQuantityDialog extends StatefulWidget {
  const _ReturnQuantityDialog({required this.item});

  final OrderReturnItem item;

  @override
  State<_ReturnQuantityDialog> createState() => _ReturnQuantityDialogState();
}

class _ReturnQuantityDialogState extends State<_ReturnQuantityDialog> {
  late final TextEditingController _quantity;
  final _quantityFocus = FocusNode();
  final _quantityKey = GlobalKey<FormFieldState<String>>();

  @override
  void initState() {
    super.initState();
    _quantity =
        TextEditingController(text: _quantityText(widget.item.quantity));
  }

  @override
  void dispose() {
    _quantity.dispose();
    _quantityFocus.dispose();
    super.dispose();
  }

  double? _parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  /// > 0 e <= maxQuantity (a pendência do teto carrega o próprio limite).
  String? _validateQuantity(String? value) {
    final quantity = _parse(value ?? '');
    if (quantity == null || quantity <= 0) {
      return 'forms.orderReturn.quantityInvalid'.tr();
    }
    if (quantity > widget.item.maxQuantity) {
      return 'forms.orderReturn.quantityMax'
          .tr(args: [_quantityText(widget.item.maxQuantity)]);
    }
    return null;
  }

  /// Valida via ponte: UMA pendência por vez, com foco no campo pendente.
  Future<void> _confirm() async {
    final ok = await _firstPendingCheck(context, [
      _DialogCheck(
        validate: () => _validateQuantity(_quantity.text),
        focusNode: _quantityFocus,
        fieldKey: _quantityKey,
      ),
    ]);
    if (!ok || !mounted) return;
    Navigator.of(context).pop(_parse(_quantity.text));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: SetesText('forms.orderReturn.editItem'.tr()),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SetesText(widget.item.productDescription ?? ''),
              const SizedBox(height: 16),
              SetesTextField(
                label: 'forms.orderReturn.quantity'.tr(),
                hint: 'forms.orderReturn.quantityMaxHint'
                    .tr(args: [_quantityText(widget.item.maxQuantity)]),
                controller: _quantity,
                focusNode: _quantityFocus,
                fieldKey: _quantityKey,
                autofocus: true,
                keyboardType: TextInputType.number,
                validator: _validateQuantity,
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

/// Dialog do faturamento da devolução: campo CFOP OBRIGATÓRIO com lista de
/// apoio (GET /api/cfop — a devolução é ajuste de Entrada, o CFOP é a
/// decisão do usuário no faturamento). Devolve o cfopId via Navigator.pop
/// — a página dispara o validate com adjustment = { cfopId }.
class _ReturnInvoiceDialog extends StatefulWidget {
  const _ReturnInvoiceDialog({required this.datasource});

  final OrderReturnDatasource datasource;

  @override
  State<_ReturnInvoiceDialog> createState() => _ReturnInvoiceDialogState();
}

class _ReturnInvoiceDialogState extends State<_ReturnInvoiceDialog> {
  String? _cfopId;
  String _cfopDisplay = '';

  Future<void> _pickCfop() async {
    final picked = await showSetesLookup<OrderReturnCfopLookup>(
      context: context,
      title: 'lookup.cfop'.tr(),
      filterHint: 'register.filterHint'.tr(),
      emptyText: 'register.emptyList'.tr(),
      onSearch: widget.datasource.cfopLookup,
      itemId: (cfop) => int.tryParse(cfop.id) ?? 0,
      itemLabel: (cfop) => cfop.description,
    );
    if (picked != null) {
      setState(() {
        _cfopId      = picked.id;
        _cfopDisplay = '${picked.id} — ${picked.description}';
      });
    }
  }

  /// Valida via ponte: o CFOP é o único campo — e é obrigatório.
  Future<void> _confirm() async {
    final ok = await _firstPendingCheck(context, [
      _DialogCheck(
        validate: () => _cfopId == null
            ? 'register.requiredField'
                .tr(args: ['forms.orderReturn.cfop'.tr()])
            : null,
      ),
    ]);
    if (!ok || !mounted) return;
    Navigator.of(context).pop(_cfopId);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: SetesText('forms.orderReturn.invoiceDialogTitle'.tr()),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SetesLookupField(
                label: 'forms.orderReturn.cfop'.tr(),
                display: _cfopDisplay,
                onSearch: _pickCfop,
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
            label: 'forms.orderReturn.validateAndInvoice'.tr(),
            kind: SetesButtonKind.text,
            onPressed: _confirm,
          ),
        ],
      );
}
