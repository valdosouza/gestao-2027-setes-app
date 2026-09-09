import 'package:core/core.dart';

import '../../domain/entity/order_entity.dart';

/// Datasource remoto do Pedido de Venda/Conjugado: /api/orders na
/// setes-api (módulo gêmeo — escopo por institution vem do JWT). Lookup de
/// cliente em /api/customers (projeção local — módulo não importa
/// módulo); lookup de vendedor reaproveita o
/// shared/lookup/salesman_lookup_datasource (já existe e já aponta pro
/// mesmo endpoint usado por customers/carriers/providers). Faturamento
/// chama /api/billing/validate + /api/billing/invoice DIRETAMENTE — não
/// existe módulo billing próprio no app (módulo nunca importa módulo).
/// Negociação (forma/prazo/parcelas) e os lookups dela (formas de
/// pagamento, bancos p/ cheque) vivem em /api/orders — NUNCA em
/// /api/checks, /api/payment-types ou /api/bank-accounts.
abstract class OrderDatasource {
  /// Página dos pedidos da institution filtrados por [status] 'A'|'F' e
  /// nome do cliente ([filter] — o filtro é da API). Paginação: [pageSize]
  /// null deixa a API resolver a config page_size do usuário.
  Future<PagedResult<OrderListItem>> getList(String status, String filter,
      {int page = 1, int? pageSize});

  /// Pedido completo (itens + totalizer) para o detalhe.
  Future<OrderFull> getById(int id);

  /// Abre o pedido para o cliente — vendedor opcional (default da carteira
  /// do cliente na API; 400 SALESMAN_REQUIRED se nenhum existir). Devolve
  /// o id.
  Future<int> open(int customerId, int? salesmanId);

  /// Cancela o pedido ABERTO (soft delete — 409 se já faturado).
  Future<void> cancel(int id);

  /// Inclui item — o backend decide mercadoria×serviço pelo kind do
  /// produto (o campo enviado é sempre só productId).
  Future<int> itemPost(int orderId, OrderItemInput input);

  /// Altera item do pedido aberto.
  Future<void> itemPut(int orderId, int itemId, OrderItemInput input);

  /// Remove item do pedido aberto.
  Future<void> itemDelete(int orderId, int itemId);

  /// Lookup de MERCADORIAS ativas (kind P/M) — só pré-preenche a busca do
  /// seletor; o campo enviado é sempre productId.
  Future<List<OrderProductLookup>> merchandiseLookup(String filter);

  /// Lookup de SERVIÇOS ativos (kind S).
  Future<List<OrderProductLookup>> serviceLookup(String filter);

  /// Clientes para o lookup do FAB "Novo pedido".
  Future<List<OrderCustomerLookup>> customers(String filter);

  /// Valida o pedido para faturamento (POST /api/billing/validate) —
  /// issues[] vazio = pronto pra faturar.
  Future<OrderBillingValidation> billingValidate(int orderId);

  /// Fatura o pedido (POST /api/billing/invoice) — só chamar depois de um
  /// validate sem issues. [checks] = cheques por parcela (bloco `checks`),
  /// obrigatório para toda parcela cuja forma é cheque (kind 'Q' — D5).
  Future<OrderBillingInvoice> billingInvoice(int orderId,
      {List<OrderParcelChecksInput> checks = const []});

  /// Negociação do pedido (GET /api/orders/:id/negotiation): cabeçalho
  /// (forma + prazo), grade elaborada, preview gerado e base do pedido.
  Future<OrderNegotiation> getNegotiation(int orderId);

  /// Grava a negociação (PUT /api/orders/:id/negotiation) e devolve a
  /// negociação RECOMPOSTA pela API (preview/base atualizados).
  Future<OrderNegotiation> putNegotiation(
      int orderId, OrderNegotiationInput input);

  /// Formas de pagamento vinculadas/habilitadas (lookup do cabeçalho e da
  /// forma por parcela) — GET /api/orders/payment-types-lookup.
  Future<List<OrderPaymentTypeLookup>> paymentTypesLookup(String filter);

  /// Bancos do catálogo para o cheque do faturamento — GET
  /// /api/orders/banks-lookup (o módulo fala SÓ com /api/orders).
  Future<List<OrderBankLookup>> banksLookup(String filter);

  /// Abre uma DEVOLUÇÃO ancorada neste pedido FATURADO (POST
  /// /api/order-returns {saleOrderId} — HTTP direto: módulo nunca importa
  /// módulo; a condução da devolução é do módulo order_returns). 422
  /// ORIGIN_NOT_INVOICED / NOTHING_RETURNABLE com mensagem pronta.
  /// Devolve o id da devolução criada.
  Future<int> openReturn(int saleOrderId);

  /// Cancela a NOTA do pedido faturado (POST /api/billing/cancel {orderId,
  /// reason} — HTTP direto no /api/billing, como validate/invoice). 409
  /// INVOICE_CANCEL_BLOCKED traz fields[] tipado (title/bankSlip/check/
  /// return) com o que resolver antes; 403 PRIVILEGE_REQUIRED sem CANCELAR.
  Future<OrderBillingCancel> billingCancel(int orderId, String reason);
}

class OrderDatasourceImpl implements OrderDatasource {
  const OrderDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<PagedResult<OrderListItem>> getList(String status, String filter,
      {int page = 1, int? pageSize}) async {
    final params = <String>[
      'status=${Uri.encodeComponent(status)}',
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'page=$page',
      if (pageSize != null) 'pageSize=$pageSize',
    ];
    final json = await client.get('/api/orders?${params.join('&')}');
    return PagedResult.fromJson(json, OrderListItem.fromJson);
  }

  @override
  Future<OrderFull> getById(int id) async {
    final json = await client.get('/api/orders/$id');
    return OrderFull.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<int> open(int customerId, int? salesmanId) async {
    final json = await client.post('/api/orders', {
      'customerId': customerId,
      if (salesmanId != null) 'salesmanId': salesmanId,
    });
    final data = json['data'] as Map<String, dynamic>? ?? const {};
    return jsonInt(data['id']) ?? 0;
  }

  @override
  Future<void> cancel(int id) async {
    await client.delete('/api/orders/$id');
  }

  @override
  Future<int> itemPost(int orderId, OrderItemInput input) async {
    final json = await client.post('/api/orders/$orderId/items', input.toJson());
    final data = json['data'] as Map<String, dynamic>? ?? const {};
    return jsonInt(data['id']) ?? 0;
  }

  @override
  Future<void> itemPut(int orderId, int itemId, OrderItemInput input) async {
    await client.put('/api/orders/$orderId/items/$itemId', input.toJson());
  }

  @override
  Future<void> itemDelete(int orderId, int itemId) async {
    await client.delete('/api/orders/$orderId/items/$itemId');
  }

  @override
  Future<List<OrderProductLookup>> merchandiseLookup(String filter) async {
    final query =
        filter.isNotEmpty ? '?filter=${Uri.encodeComponent(filter)}' : '';
    final json = await client.get('/api/orders/merchandise-lookup$query');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => OrderProductLookup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<OrderProductLookup>> serviceLookup(String filter) async {
    final query =
        filter.isNotEmpty ? '?filter=${Uri.encodeComponent(filter)}' : '';
    final json = await client.get('/api/orders/service-lookup$query');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => OrderProductLookup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<OrderCustomerLookup>> customers(String filter) async {
    final query =
        filter.isNotEmpty ? '?filter=${Uri.encodeComponent(filter)}' : '';
    final json = await client.get('/api/customers$query');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => OrderCustomerLookup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<OrderBillingValidation> billingValidate(int orderId) async {
    final json =
        await client.post('/api/billing/validate', {'orderId': orderId});
    return OrderBillingValidation.fromJson(
        json['data'] as Map<String, dynamic>);
  }

  @override
  Future<OrderBillingInvoice> billingInvoice(int orderId,
      {List<OrderParcelChecksInput> checks = const []}) async {
    final json = await client.post('/api/billing/invoice', {
      'orderId': orderId,
      if (checks.isNotEmpty) 'checks': checks.map((c) => c.toJson()).toList(),
    });
    return OrderBillingInvoice.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<OrderNegotiation> getNegotiation(int orderId) async {
    final json = await client.get('/api/orders/$orderId/negotiation');
    return OrderNegotiation.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<OrderNegotiation> putNegotiation(
      int orderId, OrderNegotiationInput input) async {
    final json =
        await client.put('/api/orders/$orderId/negotiation', input.toJson());
    return OrderNegotiation.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<List<OrderPaymentTypeLookup>> paymentTypesLookup(String filter) async {
    final query =
        filter.isNotEmpty ? '?filter=${Uri.encodeComponent(filter)}' : '';
    final json = await client.get('/api/orders/payment-types-lookup$query');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => OrderPaymentTypeLookup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<OrderBankLookup>> banksLookup(String filter) async {
    final query =
        filter.isNotEmpty ? '?filter=${Uri.encodeComponent(filter)}' : '';
    final json = await client.get('/api/orders/banks-lookup$query');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => OrderBankLookup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<OrderBillingCancel> billingCancel(int orderId, String reason) async {
    final json = await client.post('/api/billing/cancel', {
      'orderId': orderId,
      'reason': reason,
    });
    return OrderBillingCancel.fromJson(
        json['data'] as Map<String, dynamic>? ?? const {});
  }

  @override
  Future<int> openReturn(int saleOrderId) async {
    final json =
        await client.post('/api/order-returns', {'saleOrderId': saleOrderId});
    final data = json['data'] as Map<String, dynamic>? ?? const {};
    return jsonInt(data['id']) ?? 0;
  }
}
