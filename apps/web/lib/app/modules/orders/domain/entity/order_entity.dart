import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

/// Entidades do módulo orders — Pedido de Venda / Conjugado
/// (setes-api src/modules/orders, 2026-08-22). TELA DE PROCESSO (mesmo
/// padrão de service_orders): backbone tb_order + ramo tb_order_sale
/// SEMPRE presente; conjugada (mercadoria + serviço) nasce por PRESENÇA —
/// o 1º item de serviço adicionado cria o ramo tb_order_service. O app só
/// EXIBE [hasService]/[productKind]; quem decide o ramo é o backend pelo
/// kind do produto (a tela manda sempre só productId). Faturamento NÃO é
/// ação deste módulo — chama /api/billing/validate + /api/billing/invoice
/// diretamente (sem módulo billing próprio no app — módulo nunca importa
/// módulo). Datas trafegam em ISO 'yyyy-MM-dd'.

/// Linha da LISTA (GET /api/orders?status=A|F) — nomes de cliente/vendedor
/// e agregados (itens/total) vêm da API.
class OrderListItem extends Equatable {
  const OrderListItem({
    required this.id,
    this.number,
    required this.customerId,
    this.customerName,
    required this.salesmanId,
    this.salesmanName,
    this.status = 'A',
    this.dtRecord,
    this.hasService = false,
    this.itemsCount = 0,
    this.totalValue = 0,
  });

  final int     id;

  /// Sequencial do pedido por institution (MAX+1) — avatar da lista.
  final int?    number;
  final int     customerId;
  final String? customerName;
  final int     salesmanId;
  final String? salesmanName;

  /// 'A' aberto | 'F' faturado.
  final String  status;

  /// ISO 'yyyy-MM-dd'.
  final String? dtRecord;

  /// true = pedido CONJUGADO (mercadoria + serviço) — só indicador visual.
  final bool    hasService;
  final int     itemsCount;
  final double  totalValue;

  factory OrderListItem.fromJson(Map<String, dynamic> json) => OrderListItem(
        id:           jsonInt(json['id']) ?? 0,
        number:       jsonInt(json['number']),
        customerId:   jsonInt(json['customerId']) ?? 0,
        customerName: json['customerName'] as String?,
        salesmanId:   jsonInt(json['salesmanId']) ?? 0,
        salesmanName: json['salesmanName'] as String?,
        status:       json['status'] as String? ?? 'A',
        dtRecord:     json['dtRecord'] as String?,
        hasService:   json['hasService'] as bool? ?? false,
        itemsCount:   jsonInt(json['itemsCount']) ?? 0,
        totalValue:   jsonDouble(json['totalValue']) ?? 0,
      );

  @override
  List<Object?> get props => [
        id, number, customerId, customerName, salesmanId, salesmanName,
        status, dtRecord, hasService, itemsCount, totalValue,
      ];
}

/// Item do pedido (tb_order_item) — [kind] é o RAMO decidido pelo backend
/// (Sale/Service) e [productKind] o kind do produto (P mercadoria, M
/// mercadoria — decisão legado, S serviço); ambos SÓ exibição (chip de
/// mercadoria×serviço na linha). Total calculado no servidor.
class OrderItem extends Equatable {
  const OrderItem({
    required this.id,
    required this.kind,
    required this.productId,
    this.productDescription,
    this.productKind = 'P',
    this.quantity = 1,
    this.unitValue = 0,
    this.discountValue = 0,
    this.total = 0,
  });

  final int     id;

  /// 'Sale' | 'Service' — ramo do item (decisão do backend).
  final String  kind;
  final int     productId;
  final String? productDescription;

  /// 'P' | 'M' | 'S' — natureza do produto.
  final String  productKind;
  final double  quantity;
  final double  unitValue;
  final double  discountValue;
  final double  total;

  /// true = item de SERVIÇO (indicador visual da linha).
  bool get isService => kind == 'Service' || productKind == 'S';

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        id:                 jsonInt(json['id']) ?? 0,
        kind:               json['kind'] as String? ?? 'Sale',
        productId:          jsonInt(json['productId']) ?? 0,
        productDescription: json['productDescription'] as String?,
        productKind:        json['productKind'] as String? ?? 'P',
        quantity:           jsonDouble(json['quantity']) ?? 1,
        unitValue:          jsonDouble(json['unitValue']) ?? 0,
        discountValue:      jsonDouble(json['discountValue']) ?? 0,
        total:              jsonDouble(json['total']) ?? 0,
      );

  @override
  List<Object?> get props => [
        id, kind, productId, productDescription, productKind,
        quantity, unitValue, discountValue, total,
      ];
}

/// Pedido COMPLETO (GET /api/orders/:id) — itens + totalizer (o total
/// SEMPRE vem do servidor, nunca somado localmente no Flutter).
class OrderFull extends Equatable {
  const OrderFull({
    required this.id,
    this.number,
    required this.customerId,
    this.customerName,
    required this.salesmanId,
    this.salesmanName,
    this.status = 'A',
    this.dtRecord,
    this.items = const [],
    this.totalValue = 0,
  });

  final int     id;
  final int?    number;
  final int     customerId;
  final String? customerName;
  final int     salesmanId;
  final String? salesmanName;
  final String  status;
  final String? dtRecord;
  final List<OrderItem> items;
  final double  totalValue;

  bool get isOpen => status == 'A';

  /// Conjugada (derivado) — pelo menos um item de serviço presente.
  bool get hasService => items.any((item) => item.isService);

  factory OrderFull.fromJson(Map<String, dynamic> json) => OrderFull(
        id:           jsonInt(json['id']) ?? 0,
        number:       jsonInt(json['number']),
        customerId:   jsonInt(json['customerId']) ?? 0,
        customerName: json['customerName'] as String?,
        salesmanId:   jsonInt(json['salesmanId']) ?? 0,
        salesmanName: json['salesmanName'] as String?,
        status:       json['status'] as String? ?? 'A',
        dtRecord:     json['dtRecord'] as String?,
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalValue: jsonDouble(json['totalValue']) ?? 0,
      );

  @override
  List<Object?> get props => [
        id, number, customerId, customerName, salesmanId, salesmanName,
        status, dtRecord, items, totalValue,
      ];
}

/// Body do POST/PUT de item — o campo enviado é SEMPRE só productId; o
/// backend decide sozinho mercadoria×serviço pelo kind do produto.
class OrderItemInput extends Equatable {
  const OrderItemInput({
    required this.productId,
    this.quantity = 1,
    required this.unitValue,
    this.discountValue,
  });

  final int     productId;

  /// > 0 (default 1).
  final double  quantity;

  /// >= 0.
  final double  unitValue;

  /// >= 0; null = sem desconto.
  final double? discountValue;

  Map<String, dynamic> toJson() => {
        'productId':     productId,
        'quantity':      quantity,
        'unitValue':     unitValue,
        'discountValue': discountValue,
      };

  @override
  List<Object?> get props => [productId, quantity, unitValue, discountValue];
}

/// Cliente para o lookup do FAB "Novo pedido" (GET /api/customers —
/// projeção local: módulo nunca importa módulo; mesmo mecanismo do
/// service_orders).
class OrderCustomerLookup extends Equatable {
  const OrderCustomerLookup({
    required this.id,
    this.nickTrade,
    this.nameCompany,
  });

  final int     id;
  final String? nickTrade;
  final String? nameCompany;

  /// Exibição: nome fantasia, senão razão social.
  String get display => nickTrade ?? nameCompany ?? '';

  factory OrderCustomerLookup.fromJson(Map<String, dynamic> json) =>
      OrderCustomerLookup(
        id:          jsonInt(json['id']) ?? 0,
        nickTrade:   json['nickTrade'] as String?,
        nameCompany: json['nameCompany'] as String?,
      );

  @override
  List<Object?> get props => [id, nickTrade, nameCompany];
}

/// Item do lookup de produtos (GET /api/orders/merchandise-lookup |
/// /service-lookup) — [kind] só pré-preenche a busca; o campo enviado ao
/// incluir/editar item é sempre productId (o backend decide o ramo).
class OrderProductLookup extends Equatable {
  const OrderProductLookup({
    required this.id,
    this.description = '',
    this.kind = 'P',
  });

  final int    id;
  final String description;

  /// 'P' | 'M' | 'S'.
  final String kind;

  factory OrderProductLookup.fromJson(Map<String, dynamic> json) =>
      OrderProductLookup(
        id:          jsonInt(json['id']) ?? 0,
        description: json['description'] as String? ?? '',
        kind:        json['kind'] as String? ?? 'P',
      );

  @override
  List<Object?> get props => [id, description, kind];
}

// ---------------------------------------------------------------------
// Faturamento (POST /api/billing/validate + /api/billing/invoice) — o
// pedido não fatura sozinho, chama o módulo billing da API diretamente.
// ---------------------------------------------------------------------

/// Pendência de uma issue de validação (dialog de pendências).
class OrderBillingIssue extends Equatable {
  const OrderBillingIssue({
    required this.scope,
    this.itemId,
    this.field,
    this.message = '',
  });

  /// 'order' | 'emitter' | 'recipient' | 'item'.
  final String  scope;
  final int?    itemId;
  final String? field;

  /// Mensagem PRONTA vinda da API — a tela só exibe.
  final String  message;

  factory OrderBillingIssue.fromJson(Map<String, dynamic> json) =>
      OrderBillingIssue(
        scope:   json['scope'] as String? ?? 'order',
        itemId:  jsonInt(json['itemId']),
        field:   json['field'] as String?,
        message: json['message'] as String? ?? '',
      );

  @override
  List<Object?> get props => [scope, itemId, field, message];
}

/// Resultado de POST /api/billing/validate.
class OrderBillingValidation extends Equatable {
  const OrderBillingValidation({
    required this.orderId,
    this.branch = '',
    this.issues = const [],
    this.rulesResolved = 0,
    this.rulesManual = 0,
  });

  final int    orderId;
  final String branch;
  final List<OrderBillingIssue> issues;
  final int    rulesResolved;
  final int    rulesManual;

  bool get canInvoice => issues.isEmpty;

  factory OrderBillingValidation.fromJson(Map<String, dynamic> json) =>
      OrderBillingValidation(
        orderId: jsonInt(json['orderId']) ?? 0,
        branch:  json['branch'] as String? ?? '',
        issues: (json['issues'] as List<dynamic>? ?? [])
            .map((e) => OrderBillingIssue.fromJson(e as Map<String, dynamic>))
            .toList(),
        rulesResolved: jsonInt(json['rulesResolved']) ?? 0,
        rulesManual:   jsonInt(json['rulesManual']) ?? 0,
      );

  @override
  List<Object?> get props =>
      [orderId, branch, issues, rulesResolved, rulesManual];
}

/// Resultado de POST /api/billing/invoice.
class OrderBillingInvoice extends Equatable {
  const OrderBillingInvoice({
    required this.orderId,
    this.invoiceNumber = '',
    this.serie = '',
    this.model = '',
    this.totalValue = 0,
    this.parcels = 1,
    this.autoSettled = 0,
  });

  final int    orderId;
  final String invoiceNumber;
  final String serie;
  final String model;
  final double totalValue;
  final int    parcels;

  /// Parcelas baixadas automaticamente à vista (kind='E' — W3.2).
  final int    autoSettled;

  factory OrderBillingInvoice.fromJson(Map<String, dynamic> json) =>
      OrderBillingInvoice(
        orderId:       jsonInt(json['orderId']) ?? 0,
        invoiceNumber: json['invoiceNumber']?.toString() ?? '',
        serie:         json['serie']?.toString() ?? '',
        model:         json['model']?.toString() ?? '',
        totalValue:    jsonDouble(json['totalValue']) ?? 0,
        parcels:       jsonInt(json['parcels']) ?? 1,
        autoSettled:   jsonInt(json['autoSettled']) ?? 0,
      );

  @override
  List<Object?> get props =>
      [orderId, invoiceNumber, serie, model, totalValue, parcels, autoSettled];
}
