import 'package:core/core.dart';

import '../../domain/entity/order_return_entity.dart';

/// Datasource remoto da Devolução de Mercadoria: /api/order-returns na
/// setes-api (módulo gêmeo — escopo por institution vem do JWT). A
/// devolução nasce ancorada num pedido de venda FATURADO (o POST recebe
/// só saleOrderId; a API pré-carrega os itens com o saldo devolvível).
/// Faturamento chama /api/billing/validate + /api/billing/invoice
/// DIRETAMENTE com adjustment = { cfopId } (não existe módulo billing
/// próprio no app — módulo nunca importa módulo). Lookup de CFOP em
/// /api/cfop (projeção local, precedente orders → /api/customers).
abstract class OrderReturnDatasource {
  /// Página das devoluções da institution filtradas por [status] 'A'|'F' e
  /// nome do cliente ([filter] — o filtro é da API). Paginação: [pageSize]
  /// null deixa a API resolver a config page_size do usuário.
  Future<PagedResult<OrderReturnListItem>> getList(String status, String filter,
      {int page = 1, int? pageSize});

  /// Devolução completa (itens com maxQuantity + total) para o detalhe.
  Future<OrderReturnFull> getById(int id);

  /// Abre a devolução ancorada no pedido de venda FATURADO [saleOrderId] —
  /// itens pré-carregados pela API (422 ORIGIN_NOT_INVOICED /
  /// NOTHING_RETURNABLE com mensagem pronta). Devolve o id.
  Future<int> open(int saleOrderId);

  /// Cancela a devolução ABERTA (409 ORDER_INVOICED se já faturada).
  Future<void> cancel(int id);

  /// Altera a QUANTIDADE do item (único campo editável — teto =
  /// maxQuantity; 422 RETURN_INVALID acima do saldo).
  Future<void> itemQuantityPut(int returnId, int itemId, double quantity);

  /// Remove o item da devolução aberta — sem re-inclusão (removeu errado →
  /// cancela a devolução e reabre).
  Future<void> itemDelete(int returnId, int itemId);

  /// CFOPs ATIVOS para o dialog do faturamento (GET /api/cfop paginado —
  /// projeção local {id, description}).
  Future<List<OrderReturnCfopLookup>> cfopLookup(String filter);

  /// Valida a devolução para faturamento (POST /api/billing/validate com
  /// adjustment = { cfopId }) — issues[] vazio = pronto pra faturar.
  Future<OrderReturnBillingValidation> billingValidate(
      int returnId, String cfopId);

  /// Fatura a devolução (POST /api/billing/invoice com adjustment =
  /// { cfopId }) — só chamar depois de um validate sem issues.
  Future<OrderReturnBillingInvoice> billingInvoice(int returnId, String cfopId);
}

class OrderReturnDatasourceImpl implements OrderReturnDatasource {
  const OrderReturnDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<PagedResult<OrderReturnListItem>> getList(String status, String filter,
      {int page = 1, int? pageSize}) async {
    final params = <String>[
      'status=${Uri.encodeComponent(status)}',
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'page=$page',
      if (pageSize != null) 'pageSize=$pageSize',
    ];
    final json = await client.get('/api/order-returns?${params.join('&')}');
    return PagedResult.fromJson(json, OrderReturnListItem.fromJson);
  }

  @override
  Future<OrderReturnFull> getById(int id) async {
    final json = await client.get('/api/order-returns/$id');
    return OrderReturnFull.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<int> open(int saleOrderId) async {
    final json =
        await client.post('/api/order-returns', {'saleOrderId': saleOrderId});
    final data = json['data'] as Map<String, dynamic>? ?? const {};
    return jsonInt(data['id']) ?? 0;
  }

  @override
  Future<void> cancel(int id) async {
    await client.delete('/api/order-returns/$id');
  }

  @override
  Future<void> itemQuantityPut(int returnId, int itemId, double quantity) async {
    await client.put('/api/order-returns/$returnId/items/$itemId',
        {'quantity': quantity});
  }

  @override
  Future<void> itemDelete(int returnId, int itemId) async {
    await client.delete('/api/order-returns/$returnId/items/$itemId');
  }

  @override
  Future<List<OrderReturnCfopLookup>> cfopLookup(String filter) async {
    final params = <String>[
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'page=1',
      'pageSize=50',
    ];
    final json = await client.get('/api/cfop?${params.join('&')}');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => OrderReturnCfopLookup.fromJson(e as Map<String, dynamic>))
        .where((cfop) => cfop.active)
        .toList();
  }

  @override
  Future<OrderReturnBillingValidation> billingValidate(
      int returnId, String cfopId) async {
    final json = await client.post('/api/billing/validate', {
      'orderId': returnId,
      'adjustment': {'cfopId': cfopId},
    });
    return OrderReturnBillingValidation.fromJson(
        json['data'] as Map<String, dynamic>);
  }

  @override
  Future<OrderReturnBillingInvoice> billingInvoice(
      int returnId, String cfopId) async {
    final json = await client.post('/api/billing/invoice', {
      'orderId': returnId,
      'useMvaOriginal': false,
      'adjustment': {'cfopId': cfopId},
    });
    return OrderReturnBillingInvoice.fromJson(
        json['data'] as Map<String, dynamic>);
  }
}
