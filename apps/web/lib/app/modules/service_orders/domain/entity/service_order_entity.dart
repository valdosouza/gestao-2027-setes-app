import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

/// Entidades do módulo service_orders — Ordens de Serviço (Módulo Software
/// House, Onda 4; 05-ORDEM-SERVICO-SOFTWARE-HOUSE.md). 1ª TELA DE PROCESSO
/// do produto: a OS fica ABERTA o mês inteiro acumulando itens (tarefas
/// avulsas + itens de contrato injetados pela rotina mensal com pró-rata);
/// Gerar Faturamento emite a fatura interna e fecha a ordem (A→F — DP7).
/// Espelho do /api/service-orders; datas trafegam em ISO 'yyyy-MM-dd'.

/// Linha da LISTA (GET /api/service-orders?status=A|F) — nome do cliente e
/// agregados (itens/total) vêm da API.
class ServiceOrderListItem extends Equatable {
  const ServiceOrderListItem({
    required this.id,
    this.number,
    required this.customerId,
    this.customerName,
    this.status = 'A',
    this.dtRecord,
    this.itemsCount = 0,
    this.totalValue = 0,
  });

  final int     id;

  /// Sequencial da OS por institution (MAX+1) — avatar da lista.
  final int?    number;
  final int     customerId;
  final String? customerName;

  /// 'A' aberta | 'F' faturada (status vive na tb_order — DP7).
  final String  status;

  /// ISO 'yyyy-MM-dd'.
  final String? dtRecord;
  final int     itemsCount;
  final double  totalValue;

  factory ServiceOrderListItem.fromJson(Map<String, dynamic> json) =>
      ServiceOrderListItem(
        id:           jsonInt(json['id']) ?? 0,
        number:       jsonInt(json['number']),
        customerId:   jsonInt(json['customerId']) ?? 0,
        customerName: json['customerName'] as String?,
        status:       json['status'] as String? ?? 'A',
        dtRecord:     json['dtRecord'] as String?,
        itemsCount:   jsonInt(json['itemsCount']) ?? 0,
        totalValue:   jsonDouble(json['totalValue']) ?? 0,
      );

  @override
  List<Object?> get props => [
        id, number, customerId, customerName, status,
        dtRecord, itemsCount, totalValue,
      ];
}

/// Item da OS (tb_order_item kind='Service' — item universal DP6): total
/// calculado no servidor (quantity × unitValue − discountValue).
class ServiceOrderItem extends Equatable {
  const ServiceOrderItem({
    required this.id,
    required this.productId,
    this.productDescription,
    this.quantity = 1,
    this.unitValue = 0,
    this.discountValue = 0,
    this.total = 0,
  });

  final int     id;
  final int     productId;

  /// Descrição do produto (JOIN da API — só exibição).
  final String? productDescription;
  final double  quantity;
  final double  unitValue;
  final double  discountValue;
  final double  total;

  factory ServiceOrderItem.fromJson(Map<String, dynamic> json) =>
      ServiceOrderItem(
        id:                 jsonInt(json['id']) ?? 0,
        productId:          jsonInt(json['productId']) ?? 0,
        productDescription: json['productDescription'] as String?,
        quantity:           jsonDouble(json['quantity']) ?? 1,
        unitValue:          jsonDouble(json['unitValue']) ?? 0,
        discountValue:      jsonDouble(json['discountValue']) ?? 0,
        total:              jsonDouble(json['total']) ?? 0,
      );

  @override
  List<Object?> get props => [
        id, productId, productDescription,
        quantity, unitValue, discountValue, total,
      ];
}

/// OS COMPLETA (GET /api/service-orders/:id) — itens + totalizer; fatura
/// (número/emissão) preenchida quando FATURADA.
class ServiceOrderFull extends Equatable {
  const ServiceOrderFull({
    required this.id,
    this.number,
    required this.customerId,
    this.customerName,
    this.status = 'A',
    this.dtRecord,
    this.items = const [],
    this.totalValue = 0,
    this.invoiceNumber,
    this.dtEmission,
  });

  final int     id;
  final int?    number;
  final int     customerId;
  final String? customerName;
  final String  status;
  final String? dtRecord;
  final List<ServiceOrderItem> items;

  /// Totalizer recalculado no SERVIDOR a cada operação de item.
  final double  totalValue;

  /// Nº da fatura interna (tb_invoice model 'SE' — DP8); null = aberta.
  final String? invoiceNumber;

  /// ISO 'yyyy-MM-dd' da emissão; null = aberta.
  final String? dtEmission;

  bool get isOpen => status == 'A';

  factory ServiceOrderFull.fromJson(Map<String, dynamic> json) =>
      ServiceOrderFull(
        id:           jsonInt(json['id']) ?? 0,
        number:       jsonInt(json['number']),
        customerId:   jsonInt(json['customerId']) ?? 0,
        customerName: json['customerName'] as String?,
        status:       json['status'] as String? ?? 'A',
        dtRecord:     json['dtRecord'] as String?,
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => ServiceOrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalValue:    jsonDouble(json['totalValue']) ?? 0,
        invoiceNumber: json['invoiceNumber']?.toString(),
        dtEmission:    json['dtEmission'] as String?,
      );

  @override
  List<Object?> get props => [
        id, number, customerId, customerName, status, dtRecord,
        items, totalValue, invoiceNumber, dtEmission,
      ];
}

/// Body do POST/PUT de item (dialog de incluir/editar).
class ServiceOrderItemInput extends Equatable {
  const ServiceOrderItemInput({
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

/// Erro por cliente da rotina mensal (transação POR CLIENTE — falha de um
/// não derruba o lote).
class MonthlyRunError extends Equatable {
  const MonthlyRunError({required this.customerId, required this.message});

  final int    customerId;
  final String message;

  factory MonthlyRunError.fromJson(Map<String, dynamic> json) =>
      MonthlyRunError(
        customerId: jsonInt(json['customerId']) ?? 0,
        message:    json['message'] as String? ?? '',
      );

  @override
  List<Object?> get props => [customerId, message];
}

/// Relatório da rotina mensal (POST /monthly-run — D8, botão manual).
class MonthlyRunReport extends Equatable {
  const MonthlyRunReport({
    this.processed = 0,
    this.opened = 0,
    this.injected = 0,
    this.skipped = 0,
    this.errors = const [],
  });

  final int processed;
  final int opened;
  final int injected;
  final int skipped;
  final List<MonthlyRunError> errors;

  factory MonthlyRunReport.fromJson(Map<String, dynamic> json) =>
      MonthlyRunReport(
        processed: jsonInt(json['processed']) ?? 0,
        opened:    jsonInt(json['opened']) ?? 0,
        injected:  jsonInt(json['injected']) ?? 0,
        skipped:   jsonInt(json['skipped']) ?? 0,
        errors: (json['errors'] as List<dynamic>? ?? [])
            .map((e) => MonthlyRunError.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  List<Object?> get props => [processed, opened, injected, skipped, errors];
}

/// Body do Gerar Faturamento — vencimento DECIDIDO PELO USUÁRIO (DP1: a
/// sugestão do 5º dia útil é só o default da tela).
class ServiceOrderInvoiceInput extends Equatable {
  const ServiceOrderInvoiceInput({
    required this.dtExpiration,
    required this.paymentTypeId,
    this.parcels = 1,
  });

  /// ISO 'yyyy-MM-dd'.
  final String dtExpiration;
  final int    paymentTypeId;

  /// 1..99.
  final int    parcels;

  Map<String, dynamic> toJson() => {
        'dtExpiration':  dtExpiration,
        'paymentTypeId': paymentTypeId,
        'parcels':       parcels,
      };

  @override
  List<Object?> get props => [dtExpiration, paymentTypeId, parcels];
}

/// Resultado do faturamento (POST /:id/invoice).
class ServiceOrderInvoiceResult extends Equatable {
  const ServiceOrderInvoiceResult({
    this.invoiceNumber = '',
    this.parcels = 1,
    this.totalValue = 0,
  });

  final String invoiceNumber;
  final int    parcels;
  final double totalValue;

  factory ServiceOrderInvoiceResult.fromJson(Map<String, dynamic> json) =>
      ServiceOrderInvoiceResult(
        invoiceNumber: json['invoiceNumber']?.toString() ?? '',
        parcels:       jsonInt(json['parcels']) ?? 1,
        totalValue:    jsonDouble(json['totalValue']) ?? 0,
      );

  @override
  List<Object?> get props => [invoiceNumber, parcels, totalValue];
}

/// Cliente para o lookup do Abrir OS (GET /api/customers — projeção
/// local: módulo nunca importa módulo).
class ServiceCustomerLookup extends Equatable {
  const ServiceCustomerLookup({
    required this.id,
    this.nickTrade,
    this.nameCompany,
  });

  final int     id;
  final String? nickTrade;
  final String? nameCompany;

  /// Exibição: nome fantasia, senão razão social.
  String get display => nickTrade ?? nameCompany ?? '';

  factory ServiceCustomerLookup.fromJson(Map<String, dynamic> json) =>
      ServiceCustomerLookup(
        id:          jsonInt(json['id']) ?? 0,
        nickTrade:   json['nickTrade'] as String?,
        nameCompany: json['nameCompany'] as String?,
      );

  @override
  List<Object?> get props => [id, nickTrade, nameCompany];
}

/// Produto/serviço ATIVO para o lookup dos itens
/// (GET /api/service-orders/products).
class ServiceProductLookup extends Equatable {
  const ServiceProductLookup({required this.id, this.description = ''});

  final int    id;
  final String description;

  factory ServiceProductLookup.fromJson(Map<String, dynamic> json) =>
      ServiceProductLookup(
        id:          jsonInt(json['id']) ?? 0,
        description: json['description'] as String? ?? '',
      );

  @override
  List<Object?> get props => [id, description];
}

/// Forma de pagamento para o Gerar Faturamento (GET /api/payment-types —
/// projeção local; a tela filtra enable='S').
class ServicePaymentTypeLookup extends Equatable {
  const ServicePaymentTypeLookup({
    required this.id,
    this.description = '',
    this.enable = true,
  });

  final int    id;
  final String description;
  final bool   enable;

  factory ServicePaymentTypeLookup.fromJson(Map<String, dynamic> json) =>
      ServicePaymentTypeLookup(
        id:          jsonInt(json['id']) ?? 0,
        description: json['description'] as String? ?? '',
        enable:      (json['enable'] as String?) != 'N',
      );

  @override
  List<Object?> get props => [id, description, enable];
}
