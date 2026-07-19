import 'package:core/core.dart';

import '../../domain/entity/service_order_entity.dart';

/// Datasource remoto de Ordens de Serviço: /api/service-orders na
/// setes-api (módulo gêmeo — Módulo Software House, Onda 4; escopo por
/// institution vem do JWT). Lookups: cliente em /api/customers e forma de
/// pagamento em /api/payment-types (projeções locais — módulo não importa
/// módulo); produtos é endpoint próprio (/api/service-orders/products).
abstract class ServiceOrderDatasource {
  /// Ordens da institution filtradas por [status] 'A'|'F' e nome do
  /// cliente ([filter] — o filtro é da API).
  Future<List<ServiceOrderListItem>> getList(String status, String filter);

  /// OS completa (itens + totalizer + fatura quando houver).
  Future<ServiceOrderFull> getById(int id);

  /// Abre OS manual para o cliente — devolve o id (409 = já tem aberta).
  Future<int> open(int customerId);

  /// Cancela a OS ABERTA (soft delete — 409 se faturada).
  Future<void> cancel(int id);

  /// Inclui item (tarefa avulsa) — o totalizer é recalculado no servidor.
  Future<int> itemPost(int orderId, ServiceOrderItemInput input);

  /// Altera item da OS aberta.
  Future<void> itemPut(int orderId, int itemId, ServiceOrderItemInput input);

  /// Remove item da OS aberta.
  Future<void> itemDelete(int orderId, int itemId);

  /// Rotina de faturamento mensal (D8) — devolve o relatório.
  Future<MonthlyRunReport> monthlyRun(int year, int month);

  /// Gerar Faturamento (vencimento decidido pelo usuário — DP1).
  Future<ServiceOrderInvoiceResult> invoice(
      int orderId, ServiceOrderInvoiceInput input);

  /// SUGESTÃO de vencimento (5º dia útil do mês seguinte) — só o default.
  Future<String> expirationSuggestion(int year, int month);

  /// Clientes para o lookup do Abrir OS.
  Future<List<ServiceCustomerLookup>> customers(String filter);

  /// Produtos/serviços ATIVOS para o dialog de item.
  Future<List<ServiceProductLookup>> products(String filter);

  /// Formas de pagamento da institution (a tela filtra enable='S').
  Future<List<ServicePaymentTypeLookup>> paymentTypes();
}

class ServiceOrderDatasourceImpl implements ServiceOrderDatasource {
  const ServiceOrderDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<List<ServiceOrderListItem>> getList(
      String status, String filter) async {
    final params = <String>[
      'status=${Uri.encodeComponent(status)}',
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
    ];
    final json = await client.get('/api/service-orders?${params.join('&')}');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => ServiceOrderListItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ServiceOrderFull> getById(int id) async {
    final json = await client.get('/api/service-orders/$id');
    return ServiceOrderFull.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<int> open(int customerId) async {
    final json =
        await client.post('/api/service-orders', {'customerId': customerId});
    final data = json['data'] as Map<String, dynamic>? ?? const {};
    return jsonInt(data['id']) ?? 0;
  }

  @override
  Future<void> cancel(int id) async {
    await client.delete('/api/service-orders/$id');
  }

  @override
  Future<int> itemPost(int orderId, ServiceOrderItemInput input) async {
    final json = await client.post(
        '/api/service-orders/$orderId/items', input.toJson());
    final data = json['data'] as Map<String, dynamic>? ?? const {};
    return jsonInt(data['id']) ?? 0;
  }

  @override
  Future<void> itemPut(
      int orderId, int itemId, ServiceOrderItemInput input) async {
    await client.put(
        '/api/service-orders/$orderId/items/$itemId', input.toJson());
  }

  @override
  Future<void> itemDelete(int orderId, int itemId) async {
    await client.delete('/api/service-orders/$orderId/items/$itemId');
  }

  @override
  Future<MonthlyRunReport> monthlyRun(int year, int month) async {
    final json = await client.post(
        '/api/service-orders/monthly-run', {'year': year, 'month': month});
    return MonthlyRunReport.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<ServiceOrderInvoiceResult> invoice(
      int orderId, ServiceOrderInvoiceInput input) async {
    final json = await client.post(
        '/api/service-orders/$orderId/invoice', input.toJson());
    return ServiceOrderInvoiceResult.fromJson(
        json['data'] as Map<String, dynamic>);
  }

  @override
  Future<String> expirationSuggestion(int year, int month) async {
    final json = await client
        .get('/api/service-orders/expiration-suggestion?year=$year&month=$month');
    final data = json['data'] as Map<String, dynamic>? ?? const {};
    return data['dtExpiration'] as String? ?? '';
  }

  @override
  Future<List<ServiceCustomerLookup>> customers(String filter) async {
    final query =
        filter.isNotEmpty ? '?filter=${Uri.encodeComponent(filter)}' : '';
    final json = await client.get('/api/customers$query');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => ServiceCustomerLookup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<ServiceProductLookup>> products(String filter) async {
    final query =
        filter.isNotEmpty ? '?filter=${Uri.encodeComponent(filter)}' : '';
    final json = await client.get('/api/service-orders/products$query');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => ServiceProductLookup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<ServicePaymentTypeLookup>> paymentTypes() async {
    final json = await client.get('/api/payment-types');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) =>
            ServicePaymentTypeLookup.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
