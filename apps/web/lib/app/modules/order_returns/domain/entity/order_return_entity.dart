import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

/// Entidades do módulo order_returns — DEVOLUÇÃO DE MERCADORIA
/// (setes-api src/modules/order-returns, 2026-08-24). TELA DE PROCESSO
/// (molde orders): a devolução é um ajuste de ENTRADA ancorado num pedido
/// de venda FATURADO — ela NASCE na aba Faturados do orders (ação
/// "Devolver"); os itens vêm PRÉ-CARREGADOS pela API (um por produto,
/// quantidade = saldo devolvível) e o usuário só EDITA a quantidade (teto
/// [OrderReturnItem.maxQuantity]) ou REMOVE o item — não existe
/// re-inclusão (removeu errado → cancela a devolução e reabre).
/// Cliente/vendedor derivam da ORIGEM — a tela nunca pede. Faturar = mesmo
/// encadeamento do orders (/api/billing/validate → /invoice) com payload
/// adjustment = { cfopId } (CFOP escolhido pelo usuário no dialog).
/// Datas trafegam em ISO 'yyyy-MM-dd'.

/// Linha da LISTA (GET /api/order-returns?status=A|F) — nome do cliente e
/// agregados (itens/total) vêm da API.
class OrderReturnListItem extends Equatable {
  const OrderReturnListItem({
    required this.id,
    this.number,
    required this.originOrderId,
    this.originNumber,
    required this.customerId,
    this.customerName,
    this.status = 'A',
    this.dtRecord,
    this.itemsCount = 0,
    this.totalValue = 0,
  });

  final int     id;

  /// Sequencial da devolução por institution — avatar da lista.
  final int?    number;

  /// Pedido de venda FATURADO que ancora a devolução.
  final int     originOrderId;
  final int?    originNumber;
  final int     customerId;
  final String? customerName;

  /// 'A' aberta | 'F' faturada.
  final String  status;

  /// ISO 'yyyy-MM-dd'.
  final String? dtRecord;
  final int     itemsCount;
  final double  totalValue;

  /// Exibição do pedido de origem: nº sequencial, senão o id.
  String get originDisplay => '${originNumber ?? originOrderId}';

  factory OrderReturnListItem.fromJson(Map<String, dynamic> json) =>
      OrderReturnListItem(
        id:            jsonInt(json['id']) ?? 0,
        number:        jsonInt(json['number']),
        originOrderId: jsonInt(json['originOrderId']) ?? 0,
        originNumber:  jsonInt(json['originNumber']),
        customerId:    jsonInt(json['customerId']) ?? 0,
        customerName:  json['customerName'] as String?,
        status:        json['status'] as String? ?? 'A',
        dtRecord:      json['dtRecord'] as String?,
        itemsCount:    jsonInt(json['itemsCount']) ?? 0,
        totalValue:    jsonDouble(json['totalValue']) ?? 0,
      );

  @override
  List<Object?> get props => [
        id, number, originOrderId, originNumber, customerId, customerName,
        status, dtRecord, itemsCount, totalValue,
      ];
}

/// Item da devolução — PRÉ-CARREGADO pela API na abertura (um por produto
/// da origem). [maxQuantity] é o TETO de edição (saldo devolvível do
/// produto); o total é calculado no servidor.
class OrderReturnItem extends Equatable {
  const OrderReturnItem({
    required this.id,
    required this.productId,
    this.productDescription,
    this.quantity = 0,
    this.maxQuantity = 0,
    this.unitValue = 0,
    this.total = 0,
  });

  final int     id;
  final int     productId;
  final String? productDescription;
  final double  quantity;

  /// Saldo devolvível do produto — teto do dialog de quantidade.
  final double  maxQuantity;
  final double  unitValue;
  final double  total;

  factory OrderReturnItem.fromJson(Map<String, dynamic> json) =>
      OrderReturnItem(
        id:                 jsonInt(json['id']) ?? 0,
        productId:          jsonInt(json['productId']) ?? 0,
        productDescription: json['productDescription'] as String?,
        quantity:           jsonDouble(json['quantity']) ?? 0,
        maxQuantity:        jsonDouble(json['maxQuantity']) ?? 0,
        unitValue:          jsonDouble(json['unitValue']) ?? 0,
        total:              jsonDouble(json['total']) ?? 0,
      );

  @override
  List<Object?> get props =>
      [id, productId, productDescription, quantity, maxQuantity, unitValue, total];
}

/// Devolução COMPLETA (GET /api/order-returns/:id) — itens + total (o
/// total SEMPRE vem do servidor, nunca somado localmente no Flutter).
class OrderReturnFull extends Equatable {
  const OrderReturnFull({
    required this.id,
    this.number,
    this.status = 'A',
    this.dtRecord,
    required this.originOrderId,
    this.originNumber,
    required this.customerId,
    this.customerName,
    this.totalValue = 0,
    this.items = const [],
  });

  final int     id;
  final int?    number;
  final String  status;
  final String? dtRecord;
  final int     originOrderId;
  final int?    originNumber;
  final int     customerId;
  final String? customerName;
  final double  totalValue;
  final List<OrderReturnItem> items;

  bool get isOpen => status == 'A';

  String get originDisplay => '${originNumber ?? originOrderId}';

  factory OrderReturnFull.fromJson(Map<String, dynamic> json) =>
      OrderReturnFull(
        id:            jsonInt(json['id']) ?? 0,
        number:        jsonInt(json['number']),
        status:        json['status'] as String? ?? 'A',
        dtRecord:      json['dtRecord'] as String?,
        originOrderId: jsonInt(json['originOrderId']) ?? 0,
        originNumber:  jsonInt(json['originNumber']),
        customerId:    jsonInt(json['customerId']) ?? 0,
        customerName:  json['customerName'] as String?,
        totalValue:    jsonDouble(json['totalValue']) ?? 0,
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => OrderReturnItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  List<Object?> get props => [
        id, number, status, dtRecord, originOrderId, originNumber,
        customerId, customerName, totalValue, items,
      ];
}

/// CFOP para o dialog do faturamento (GET /api/cfop — projeção LOCAL:
/// módulo nunca importa módulo, precedente orders → /api/customers). O id
/// é o PRÓPRIO código CFOP (string) — é ele que viaja em
/// adjustment.cfopId.
class OrderReturnCfopLookup extends Equatable {
  const OrderReturnCfopLookup({
    required this.id,
    this.description = '',
    this.active = true,
  });

  final String id;
  final String description;
  final bool   active;

  factory OrderReturnCfopLookup.fromJson(Map<String, dynamic> json) =>
      OrderReturnCfopLookup(
        id:          json['id'] as String? ?? '',
        description: json['description'] as String? ?? '',
        active:      (json['active'] as String?) != 'N',
      );

  @override
  List<Object?> get props => [id, description, active];
}

// ---------------------------------------------------------------------
// Faturamento (POST /api/billing/validate + /api/billing/invoice) — mesmo
// encadeamento do orders, com adjustment = { cfopId } no payload (a
// devolução é ajuste de Entrada). Projeções próprias: módulo nunca
// importa módulo.
// ---------------------------------------------------------------------

/// Pendência de uma issue de validação (dialog de pendências).
class OrderReturnBillingIssue extends Equatable {
  const OrderReturnBillingIssue({
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

  factory OrderReturnBillingIssue.fromJson(Map<String, dynamic> json) =>
      OrderReturnBillingIssue(
        scope:   json['scope'] as String? ?? 'order',
        itemId:  jsonInt(json['itemId']),
        field:   json['field'] as String?,
        message: json['message'] as String? ?? '',
      );

  @override
  List<Object?> get props => [scope, itemId, field, message];
}

/// Resultado de POST /api/billing/validate.
class OrderReturnBillingValidation extends Equatable {
  const OrderReturnBillingValidation({
    required this.orderId,
    this.branch = '',
    this.issues = const [],
  });

  final int    orderId;
  final String branch;
  final List<OrderReturnBillingIssue> issues;

  bool get canInvoice => issues.isEmpty;

  factory OrderReturnBillingValidation.fromJson(Map<String, dynamic> json) =>
      OrderReturnBillingValidation(
        orderId: jsonInt(json['orderId']) ?? 0,
        branch:  json['branch'] as String? ?? '',
        issues: (json['issues'] as List<dynamic>? ?? [])
            .map((e) =>
                OrderReturnBillingIssue.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  List<Object?> get props => [orderId, branch, issues];
}

/// Resultado de POST /api/billing/invoice.
class OrderReturnBillingInvoice extends Equatable {
  const OrderReturnBillingInvoice({
    required this.orderId,
    this.invoiceNumber = '',
    this.serie = '',
    this.model = '',
    this.totalValue = 0,
  });

  final int    orderId;
  final String invoiceNumber;
  final String serie;
  final String model;
  final double totalValue;

  factory OrderReturnBillingInvoice.fromJson(Map<String, dynamic> json) =>
      OrderReturnBillingInvoice(
        orderId:       jsonInt(json['orderId']) ?? 0,
        invoiceNumber: json['invoiceNumber']?.toString() ?? '',
        serie:         json['serie']?.toString() ?? '',
        model:         json['model']?.toString() ?? '',
        totalValue:    jsonDouble(json['totalValue']) ?? 0,
      );

  @override
  List<Object?> get props => [orderId, invoiceNumber, serie, model, totalValue];
}
