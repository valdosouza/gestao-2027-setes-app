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

  /// ISO 'yyyy-MM-dd'. VAZIO só é válido no LOTE (D13): significa "cada ordem
  /// vence no dia do seu contrato" — a API deriva por ordem.
  final String dtExpiration;
  final int    paymentTypeId;

  /// 1..99.
  final int    parcels;

  Map<String, dynamic> toJson() => {
        // D13: vencimento vazio NÃO viaja — a ausência é que diz à API para
        // usar o dia do contrato de cada ordem.
        if (dtExpiration.isNotEmpty) 'dtExpiration': dtExpiration,
        // D14: forma 0 também NÃO viaja — a ausência é que diz à API para usar
        // a forma combinada no contrato de cada ordem.
        if (paymentTypeId > 0) 'paymentTypeId': paymentTypeId,
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

/// Uma linha do relatório do LOTE (D6/D7 da fase Primeiro Cliente): o
/// resultado REAL de cada ordem — a que falhou traz o motivo legível da API.
class BatchInvoiceEntry extends Equatable {
  const BatchInvoiceEntry({
    required this.orderId,
    required this.ok,
    this.dtExpiration = '',
    this.paymentTypeId = 0,
    this.invoiceNumber = '',
    this.totalValue = 0,
    this.autoSettled = 0,
    this.bankSlipsIssued = 0,
    this.chargedParcels = 0,
    this.chargeableParcels = 0,
    this.error = '',
    this.code = '',
    this.retryable = false,
  });

  /// Linha que a TELA fabrica quando um bloco do lote nem chegou à API (D27:
  /// a seleção é fatiada em blocos e um bloco pode falhar inteiro — sem
  /// privilégio, sem rede). As ordens dele entram no relatório como recusadas
  /// com o motivo da falha, para o relatório continuar sendo a prova completa.
  const BatchInvoiceEntry.aborted({required this.orderId, required this.error})
      : ok = false,
        dtExpiration = '',
        paymentTypeId = 0,
        invoiceNumber = '',
        totalValue = 0,
        autoSettled = 0,
        bankSlipsIssued = 0,
        chargedParcels = 0,
        chargeableParcels = 0,
        code = abortedCode,
        retryable = true;

  /// Código local (não vem da API) da linha de bloco interrompido.
  static const abortedCode = 'BATCH_ABORTED';

  final int    orderId;
  final bool   ok;

  /// Vencimento REALMENTE usado nesta ordem — com a D13 ele varia por cliente.
  final String dtExpiration;

  /// Forma REALMENTE usada nesta ordem (D14 — varia por cliente; 0 = não veio).
  final int    paymentTypeId;
  final String invoiceNumber;
  final double totalValue;

  /// O que a automação fez nesta ordem (baixa por contrato × boleto).
  final int    autoSettled;
  final int    bankSlipsIssued;

  /// D26 (Q-P5): cobrança POR PARCELA — `chargedParcels` de `chargeableParcels`.
  /// Menor que o total = cobrança PARCIAL (nota de 3 parcelas com 1 boleto).
  final int    chargedParcels;
  final int    chargeableParcels;
  final String error;
  final String code;

  /// D25 (Q-P3): recusada por contenção que a passada extra da API não
  /// resolveu — "tente de novo" é do operador (a linha fica marcada).
  final bool   retryable;

  /// Faturada mas com alguma parcela sem baixa e sem boleto (D26).
  bool get uncharged => ok && chargedParcels < chargeableParcels;

  /// Cobrança parcial: alguma parcela cobrada, alguma não (D26).
  bool get partiallyCharged =>
      ok && chargedParcels > 0 && chargedParcels < chargeableParcels;

  factory BatchInvoiceEntry.fromJson(Map<String, dynamic> json) =>
      BatchInvoiceEntry(
        orderId:       jsonInt(json['orderId']) ?? 0,
        ok:            json['ok'] == true,
        dtExpiration:  json['dtExpiration'] as String? ?? '',
        paymentTypeId: jsonInt(json['paymentTypeId']) ?? 0,
        invoiceNumber: json['invoiceNumber']?.toString() ?? '',
        totalValue:    jsonDouble(json['totalValue']) ?? 0,
        autoSettled:     jsonInt(json['autoSettled']) ?? 0,
        bankSlipsIssued: jsonInt(json['bankSlipsIssued']) ?? 0,
        chargedParcels:    jsonInt(json['chargedParcels']) ?? 0,
        chargeableParcels: jsonInt(json['chargeableParcels']) ?? 0,
        error:         json['error'] as String? ?? '',
        code:          json['code'] as String? ?? '',
        retryable:     json['retryable'] == true,
      );

  @override
  List<Object?> get props =>
      [orderId, ok, dtExpiration, paymentTypeId, invoiceNumber, totalValue,
       autoSettled, bankSlipsIssued, chargedParcels, chargeableParcels, error,
       code, retryable];
}

/// D27 (Q-P6, Valdo 2026-09-19): teto de ordens por REQUISIÇÃO na API. A
/// tela não recusa seleção maior — fatia em blocos deste tamanho, chama a API
/// bloco a bloco e AGREGA os relatórios ([BatchInvoiceReport.merge]).
const int batchInvoiceChunkSize = 50;

/// Relatório do lote (POST /batch-invoice). A API responde 200 mesmo com
/// falhas parciais — quem diz o que aconteceu é [failed] e [results].
class BatchInvoiceReport extends Equatable {
  const BatchInvoiceReport({
    this.requested = 0,
    this.invoiced = 0,
    this.failed = 0,
    this.uncharged = 0,
    this.partiallyCharged = 0,
    this.retryable = 0,
    this.results = const [],
  });

  final int requested;
  final int invoiced;
  final int failed;

  /// Faturadas com QUALQUER parcela sem baixa e sem boleto — "faturada" não
  /// quer dizer "cobrada" (gate adversarial da Onda 1); D26: a parcial conta.
  final int uncharged;

  /// Subconjunto de [uncharged] com cobrança PARCIAL (D26).
  final int partiallyCharged;

  /// Recusadas que valem repetir (D25: contenção que a passada extra não
  /// resolveu; D27: bloco que nem chegou à API).
  final int retryable;
  final List<BatchInvoiceEntry> results;

  factory BatchInvoiceReport.fromJson(Map<String, dynamic> json) =>
      BatchInvoiceReport(
        requested: jsonInt(json['requested']) ?? 0,
        invoiced:  jsonInt(json['invoiced']) ?? 0,
        failed:    jsonInt(json['failed']) ?? 0,
        uncharged: jsonInt(json['uncharged']) ?? 0,
        partiallyCharged: jsonInt(json['partiallyCharged']) ?? 0,
        retryable: jsonInt(json['retryable']) ?? 0,
        results: (json['results'] as List<dynamic>? ?? [])
            .map((e) => BatchInvoiceEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Relatório derivado só das LINHAS — é como a tela agrega os blocos (D27)
  /// e como fabrica o relatório de um bloco interrompido. Os contadores são
  /// sempre recontados das linhas, nunca somados dos parciais: a fonte é uma.
  factory BatchInvoiceReport.fromEntries(List<BatchInvoiceEntry> entries) =>
      BatchInvoiceReport(
        requested: entries.length,
        invoiced:  entries.where((e) => e.ok).length,
        failed:    entries.where((e) => !e.ok).length,
        uncharged: entries.where((e) => e.uncharged).length,
        partiallyCharged: entries.where((e) => e.partiallyCharged).length,
        retryable: entries.where((e) => !e.ok && e.retryable).length,
        results:   List.unmodifiable(entries),
      );

  /// Agrega os relatórios dos blocos na ORDEM em que rodaram (D27).
  static BatchInvoiceReport merge(Iterable<BatchInvoiceReport> parts) =>
      BatchInvoiceReport.fromEntries(
          [for (final p in parts) ...p.results]);

  @override
  List<Object?> get props =>
      [requested, invoiced, failed, uncharged, partiallyCharged, retryable,
       results];
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


/// Resultado do "Cancelar nota" da OS (POST /api/billing/cancel — Q-G16 do
/// cancelamento de nota): a nota some (soft-delete), a OS volta a ABERTA
/// (trava D5 restaurada); a API informa o que desfez junto.
class ServiceOrderInvoiceCancelResult extends Equatable {
  const ServiceOrderInvoiceCancelResult({
    required this.orderId,
    this.invoiceNumber = '',
    this.event = 0,
  });

  final int    orderId;
  final String invoiceNumber;
  /// Nº do evento C na história da nota.
  final int    event;

  factory ServiceOrderInvoiceCancelResult.fromJson(Map<String, dynamic> json) =>
      ServiceOrderInvoiceCancelResult(
        orderId:       jsonInt(json['orderId']) ?? 0,
        invoiceNumber: json['invoiceNumber']?.toString() ?? '',
        event:         jsonInt(json['event']) ?? 0,
      );

  @override
  List<Object?> get props => [orderId, invoiceNumber, event];
}
