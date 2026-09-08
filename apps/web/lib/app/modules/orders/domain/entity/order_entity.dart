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

// ---------------------------------------------------------------------
// Negociação do pedido (GET/PUT /api/orders/:id/negotiation —
// prompt_negociacao_pedido.md D1–D7): via SIMPLES = cabeçalho
// (tb_order_billing: forma + prazo string) × via ELABORADA = grade
// (tb_order_installment). `mode` é DERIVADO da presença da grade — nunca
// coluna; `preview` = parcelas GERADAS do prazo (nunca gravadas).
// ---------------------------------------------------------------------

/// Kind da forma de pagamento que exige cheques no faturamento (D5).
const kPaymentKindCheck = 'Q';

/// Teto de dias por parcela do prazo (MAX_DEADLINE_DAYS da API) — a tela
/// espelha o normalizador para a pendência nascer local (D-N4).
const kMaxDeadlineDays = 3650;

/// Parcela da negociação — vale tanto para a grade ELABORADA gravada
/// quanto para o `preview` gerado do prazo. [paymentTypeId] já vem
/// RESOLVIDO (cabeçalho quando a parcela não tem a sua);
/// [ownPaymentType] diz se a forma é PRÓPRIA (só na elaborada).
class OrderNegotiationParcel extends Equatable {
  const OrderNegotiationParcel({
    required this.parcel,
    required this.dueDate,
    required this.amount,
    required this.paymentTypeId,
    this.paymentTypeDescription,
    this.paymentTypeKind,
    this.ownPaymentType = false,
  });

  final int     parcel;

  /// ISO 'yyyy-MM-dd'.
  final String  dueDate;
  final double  amount;
  final int     paymentTypeId;
  final String? paymentTypeDescription;

  /// E espécie · X PIX · Q cheque · B boleto · A carteira · C cartão · O outros.
  final String? paymentTypeKind;
  final bool    ownPaymentType;

  /// Parcela paga em CHEQUE — o faturamento exige os cheques dela (D5).
  bool get isCheck => paymentTypeKind == kPaymentKindCheck;

  factory OrderNegotiationParcel.fromJson(Map<String, dynamic> json) =>
      OrderNegotiationParcel(
        parcel:                 jsonInt(json['parcel']) ?? 0,
        dueDate:                json['dueDate'] as String? ?? '',
        amount:                 jsonDouble(json['amount']) ?? 0,
        paymentTypeId:          jsonInt(json['paymentTypeId']) ?? 0,
        paymentTypeDescription: json['paymentTypeDescription'] as String?,
        paymentTypeKind:        json['paymentTypeKind'] as String?,
        ownPaymentType:         json['ownPaymentType'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [
        parcel, dueDate, amount, paymentTypeId, paymentTypeDescription,
        paymentTypeKind, ownPaymentType,
      ];
}

/// Cabeçalho da negociação (via SIMPLES — tb_order_billing 1:1): forma +
/// prazo; [maxParcels] é o limite que a institution concede na forma.
///
/// Prazo (D-N4, 2026-09-07): [deadline] é o texto COMO GRAVADO — pode ser
/// legado do sync ('A VISTA', '30/60/90 DIAS') que não passa no
/// normalizador estrito da API; [deadlineValid] diz se passa e
/// [deadlineCanonical] é a forma '028/056/084' (null = à vista) quando
/// passa. A API aceita o MESMO texto legado de volta enquanto o usuário
/// não o mexer; qualquer prazo novo é estrito — a tela avisa e valida
/// localmente com a mesma regra.
class OrderNegotiationBilling extends Equatable {
  const OrderNegotiationBilling({
    required this.paymentTypeId,
    this.paymentTypeDescription,
    this.paymentTypeKind,
    this.maxParcels,
    this.deadline,
    this.deadlineCanonical,
    this.deadlineValid = true,
    this.plots,
  });

  final int     paymentTypeId;
  final String? paymentTypeDescription;
  final String? paymentTypeKind;
  final int?    maxParcels;

  /// String livre de dias por parcela ('028/056/084'; null = à vista).
  final String? deadline;

  /// Prazo canônico ('028/056/084'; null = à vista) — só quando
  /// [deadlineValid]; null também quando o gravado é legado.
  final String? deadlineCanonical;

  /// false = prazo LEGADO tolerado (a API aceita o mesmo texto de volta).
  final bool    deadlineValid;
  final int?    plots;

  bool get isCheck => paymentTypeKind == kPaymentKindCheck;

  /// Prazo legado do sync — a tela avisa e só valida se o usuário mexer.
  bool get isLegacyDeadline => !deadlineValid;

  /// Gravado válido mas fora da forma canônica (ex.: '30/60' por SQL) —
  /// a tela mostra como será regravado. Só quando a API MANDOU o canônico
  /// (null = à vista ou contrato sem o campo — nunca avisa por ausência).
  bool get deadlineNeedsCanonical =>
      deadlineValid &&
      deadlineCanonical != null &&
      (deadline ?? '') != deadlineCanonical;

  factory OrderNegotiationBilling.fromJson(Map<String, dynamic> json) =>
      OrderNegotiationBilling(
        paymentTypeId:          jsonInt(json['paymentTypeId']) ?? 0,
        paymentTypeDescription: json['paymentTypeDescription'] as String?,
        paymentTypeKind:        json['paymentTypeKind'] as String?,
        maxParcels:             jsonInt(json['maxParcels']),
        deadline:               json['deadline'] as String?,
        deadlineCanonical:      json['deadlineCanonical'] as String?,
        deadlineValid:          json['deadlineValid'] as bool? ?? true,
        plots:                  jsonInt(json['plots']),
      );

  @override
  List<Object?> get props => [
        paymentTypeId, paymentTypeDescription, paymentTypeKind, maxParcels,
        deadline, deadlineCanonical, deadlineValid, plots,
      ];
}

/// Base do PEDIDO (itens set_financial + frete, SEM impostos — D4/D7): a
/// grade elaborada precisa somar exatamente [base].
class OrderNegotiationBase extends Equatable {
  const OrderNegotiationBase({
    this.itemsValue = 0,
    this.freight = 0,
    this.base = 0,
  });

  final double itemsValue;
  final double freight;
  final double base;

  factory OrderNegotiationBase.fromJson(Map<String, dynamic> json) =>
      OrderNegotiationBase(
        itemsValue: jsonDouble(json['itemsValue']) ?? 0,
        freight:    jsonDouble(json['freight']) ?? 0,
        base:       jsonDouble(json['base']) ?? 0,
      );

  @override
  List<Object?> get props => [itemsValue, freight, base];
}

/// Negociação completa do pedido (GET/PUT /api/orders/:id/negotiation).
class OrderNegotiation extends Equatable {
  const OrderNegotiation({
    required this.orderId,
    this.status = 'A',
    this.mode = 'simple',
    this.billing,
    this.base = const OrderNegotiationBase(),
    this.installments = const [],
    this.preview = const [],
  });

  final int    orderId;

  /// 'A' aberto (editável) | 'F' faturado (somente leitura).
  final String status;

  /// 'simple' | 'elaborated' — DERIVADO da presença de [installments].
  final String mode;
  final OrderNegotiationBilling? billing;
  final OrderNegotiationBase base;

  /// Grade ELABORADA gravada (vazia na via simples).
  final List<OrderNegotiationParcel> installments;

  /// Grade GERADA do prazo a partir de hoje (nunca gravada).
  final List<OrderNegotiationParcel> preview;

  bool get isOpen       => status == 'A';
  bool get isElaborated => mode == 'elaborated';

  /// Parcelas que o faturamento vai usar: a grade elaborada quando existe,
  /// senão a gerada do prazo (decisão 25 — presença decide).
  List<OrderNegotiationParcel> get effectiveParcels =>
      isElaborated ? installments : preview;

  /// Alguma parcela é cheque → o "Validar e Faturar" abre o dialog (D5).
  bool get hasCheckParcel => effectiveParcels.any((p) => p.isCheck);

  factory OrderNegotiation.fromJson(Map<String, dynamic> json) =>
      OrderNegotiation(
        orderId: jsonInt(json['orderId']) ?? 0,
        status:  json['status'] as String? ?? 'A',
        mode:    json['mode'] as String? ?? 'simple',
        billing: json['billing'] is Map<String, dynamic>
            ? OrderNegotiationBilling.fromJson(
                json['billing'] as Map<String, dynamic>)
            : null,
        base: json['base'] is Map<String, dynamic>
            ? OrderNegotiationBase.fromJson(json['base'] as Map<String, dynamic>)
            : const OrderNegotiationBase(),
        installments: (json['installments'] as List<dynamic>? ?? [])
            .map((e) =>
                OrderNegotiationParcel.fromJson(e as Map<String, dynamic>))
            .toList(),
        preview: (json['preview'] as List<dynamic>? ?? [])
            .map((e) =>
                OrderNegotiationParcel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  List<Object?> get props =>
      [orderId, status, mode, billing, base, installments, preview];
}

/// Linha da grade ELABORADA no PUT — [paymentTypeId] null = HERDA a forma
/// do cabeçalho (o app NUNCA copia o id do cabeçalho por default — M2).
class OrderInstallmentInput extends Equatable {
  const OrderInstallmentInput({
    required this.parcel,
    required this.dueDate,
    required this.amount,
    this.paymentTypeId,
  });

  final int     parcel;

  /// ISO 'yyyy-MM-dd'.
  final String  dueDate;
  final double  amount;
  final int?    paymentTypeId;

  Map<String, dynamic> toJson() => {
        'parcel':        parcel,
        'dueDate':       dueDate,
        'amount':        amount,
        'paymentTypeId': paymentTypeId,
      };

  @override
  List<Object?> get props => [parcel, dueDate, amount, paymentTypeId];
}

/// Body do PUT /api/orders/:id/negotiation. [installments] presente e não
/// vazio = via ELABORADA (substitui a grade inteira); null = "voltar ao
/// prazo" (a API apaga o elaborado e a via simples volta a valer).
class OrderNegotiationInput extends Equatable {
  const OrderNegotiationInput({
    required this.paymentTypeId,
    this.deadline,
    this.installments,
  });

  final int    paymentTypeId;

  /// Dias por parcela ('028/056/084'); null/vazio = à vista.
  final String? deadline;
  final List<OrderInstallmentInput>? installments;

  bool get isElaborated => installments != null && installments!.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'paymentTypeId': paymentTypeId,
        'deadline':      (deadline == null || deadline!.trim().isEmpty)
            ? null
            : deadline!.trim(),
        if (isElaborated)
          'installments': installments!.map((i) => i.toJson()).toList(),
      };

  @override
  List<Object?> get props => [paymentTypeId, deadline, installments];
}

/// Forma de pagamento vinculada/habilitada (GET /api/orders/payment-types-
/// lookup) — cabeçalho e forma por parcela da negociação.
class OrderPaymentTypeLookup extends Equatable {
  const OrderPaymentTypeLookup({
    required this.id,
    this.description = '',
    this.kind = '',
    this.maxParcels = 1,
  });

  final int    id;
  final String description;
  final String kind;
  final int    maxParcels;

  bool get isCheck => kind == kPaymentKindCheck;

  factory OrderPaymentTypeLookup.fromJson(Map<String, dynamic> json) =>
      OrderPaymentTypeLookup(
        id:          jsonInt(json['id']) ?? 0,
        description: json['description'] as String? ?? '',
        kind:        json['kind'] as String? ?? '',
        maxParcels:  jsonInt(json['maxParcels']) ?? 1,
      );

  @override
  List<Object?> get props => [id, description, kind, maxParcels];
}

/// Banco do catálogo central (GET /api/orders/banks-lookup) — só para o
/// cheque do faturamento; o módulo do app fala SÓ com /api/orders.
class OrderBankLookup extends Equatable {
  const OrderBankLookup({required this.id, this.number = '', this.description});

  final int     id;
  final String  number;
  final String? description;

  /// Exibição: 'número - descrição'.
  String get display => description == null || description!.isEmpty
      ? number
      : '$number - $description';

  factory OrderBankLookup.fromJson(Map<String, dynamic> json) => OrderBankLookup(
        id:          jsonInt(json['id']) ?? 0,
        number:      json['number']?.toString() ?? '',
        description: json['description'] as String?,
      );

  @override
  List<Object?> get props => [id, number, description];
}

/// Kind do cheque: P próprio (do pagador) · T de terceiro.
abstract final class OrderCheckKind {
  static const own   = 'P';
  static const third = 'T';
}

/// UM cheque de uma parcela — vai no bloco `checks` do POST
/// /api/billing/invoice (D5: o cheque só existe quando o faturamento
/// acontece; nada é persistido antes). [bankLabel] é só exibição local.
class OrderCheckInput extends Equatable {
  const OrderCheckInput({
    required this.bankId,
    this.bankLabel = '',
    required this.agency,
    required this.account,
    required this.number,
    required this.issuer,
    required this.value,
    required this.dtCheck,
    this.kind = OrderCheckKind.own,
  });

  final int    bankId;
  final String bankLabel;
  final String agency;
  final String account;
  final String number;
  final String issuer;
  final double value;

  /// "Bom para" — ISO 'yyyy-MM-dd'.
  final String dtCheck;

  /// 'P' | 'T' (ver [OrderCheckKind]).
  final String kind;

  Map<String, dynamic> toJson() => {
        'bankId':  bankId,
        'agency':  agency,
        'account': account,
        'number':  number,
        'issuer':  issuer,
        'value':   value,
        'dtCheck': dtCheck,
        'kind':    kind,
      };

  @override
  List<Object?> get props =>
      [bankId, bankLabel, agency, account, number, issuer, value, dtCheck, kind];
}

/// Cheques de UMA parcela (soma = valor da parcela — validado local e no
/// servidor: 422 CHECK_SUM_MISMATCH, D7 pode exigir ajuste na 1ª).
class OrderParcelChecksInput extends Equatable {
  const OrderParcelChecksInput({required this.parcel, required this.items});

  final int parcel;
  final List<OrderCheckInput> items;

  double get sum => items.fold(0.0, (acc, c) => acc + c.value);

  Map<String, dynamic> toJson() => {
        'parcel': parcel,
        'items':  items.map((c) => c.toJson()).toList(),
      };

  @override
  List<Object?> get props => [parcel, items];
}
