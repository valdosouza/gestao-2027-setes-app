import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

/// Entidades do módulo bank_slips — Boletos (tela de PROCESSO, grupo
/// Financeiro; prompt_boleto_emitido.md D1–D11). Boleto = instrumento de
/// cobrança de 1..N títulos do MESMO cliente; o cabeçalho é IMUTÁVEL após a
/// emissão (taxas/instruções congeladas da carteira) e o estado é DERIVADO
/// do último evento no servidor: 'open' | 'settled' | 'cancelled'.
/// Espelho do /api/bank-slips; datas em ISO 'yyyy-MM-dd'.

/// Estados derivados do boleto (query `?status=` e campo `state`).
abstract final class BankSlipStatus {
  static const open = 'open';
  static const settled = 'settled';
  static const cancelled = 'cancelled';
}

/// Kinds dos eventos desta onda (D4): E emitido · L liquidado ·
/// C cancelado · X estornado (S/G reservados ao canal CNAB).
abstract final class BankSlipEventKind {
  static const issued = 'E';
  static const settled = 'L';
  static const cancelled = 'C';
  static const reversed = 'X';
}

/// Linha da lista (GET /api/bank-slips) — cabeçalho resumido + estado.
class BankSlipListRow extends Equatable {
  const BankSlipListRow({
    required this.id,
    this.ourNumber = '',
    this.documentNumber = '',
    this.dtEmission,
    this.dtExpiration,
    this.value = 0,
    this.state = BankSlipStatus.open,
    this.bankAccountLabel,
    this.customerName,
    this.titles = 0,
  });

  final int     id;
  final String  ourNumber;
  final String  documentNumber;
  final String? dtEmission;
  final String? dtExpiration;

  /// Soma dos títulos (congelada na emissão).
  final double  value;

  /// 'open' | 'settled' | 'cancelled' — derivado no servidor.
  final String  state;
  final String? bankAccountLabel;
  final String? customerName;

  /// Quantidade de títulos vinculados.
  final int     titles;

  bool get isOpen => state == BankSlipStatus.open;
  bool get isSettled => state == BankSlipStatus.settled;
  bool get isCancelled => state == BankSlipStatus.cancelled;

  factory BankSlipListRow.fromJson(Map<String, dynamic> json) =>
      BankSlipListRow(
        id:               jsonInt(json['id']) ?? 0,
        ourNumber:        json['ourNumber']?.toString() ?? '',
        documentNumber:   json['documentNumber']?.toString() ?? '',
        dtEmission:       json['dtEmission'] as String?,
        dtExpiration:     json['dtExpiration'] as String?,
        value:            jsonDouble(json['value']) ?? 0,
        state:            json['state'] as String? ?? BankSlipStatus.open,
        bankAccountLabel: json['bankAccountLabel'] as String?,
        customerName:     json['customerName'] as String?,
        titles:           jsonInt(json['titles']) ?? 0,
      );

  @override
  List<Object?> get props => [
        id, ourNumber, documentNumber, dtEmission, dtExpiration, value,
        state, bankAccountLabel, customerName, titles,
      ];
}

/// Título vinculado ao boleto (tb_bank_slip_title — vínculo imutável).
class BankSlipTitleRow extends Equatable {
  const BankSlipTitleRow({
    required this.orderId,
    required this.parcel,
    this.number,
    this.value = 0,
    this.entityName,
    this.dtExpiration,
  });

  final int     orderId;
  final int     parcel;
  final String? number;

  /// Parcela do título DENTRO do boleto (rateio nasce aqui).
  final double  value;
  final String? entityName;
  final String? dtExpiration;

  factory BankSlipTitleRow.fromJson(Map<String, dynamic> json) =>
      BankSlipTitleRow(
        orderId:      jsonInt(json['orderId']) ?? 0,
        parcel:       jsonInt(json['parcel']) ?? 0,
        number:       json['number'] as String?,
        value:        jsonDouble(json['value']) ?? 0,
        entityName:   json['entityName'] as String?,
        dtExpiration: json['dtExpiration'] as String?,
      );

  @override
  List<Object?> get props =>
      [orderId, parcel, number, value, entityName, dtExpiration];
}

/// Evento da história do boleto (tb_bank_slip_event, append-only).
class BankSlipEventRow extends Equatable {
  const BankSlipEventRow({
    required this.event,
    required this.kind,
    this.dtRecord,
    this.source,
    this.settledCode,
    this.paidValue,
    this.bankCode,
    this.bankMessage,
    this.originEvent,
    this.note,
    this.userId,
  });

  final int     event;

  /// 'E' | 'L' | 'C' | 'X' (ver [BankSlipEventKind]).
  final String  kind;
  final String? dtRecord;

  /// 'M' manual | 'R' retorno | 'A' API.
  final String? source;
  final int?    settledCode;
  final double? paidValue;
  final String? bankCode;
  final String? bankMessage;

  /// Evento invertido pelo estorno ('X').
  final int?    originEvent;
  final String? note;
  final int?    userId;

  factory BankSlipEventRow.fromJson(Map<String, dynamic> json) => BankSlipEventRow(
        event:       jsonInt(json['event']) ?? 0,
        kind:        json['kind'] as String? ?? '',
        dtRecord:    json['dtRecord'] as String?,
        source:      json['source'] as String?,
        settledCode: jsonInt(json['settledCode']),
        paidValue:   jsonDouble(json['paidValue']),
        bankCode:    json['bankCode'] as String?,
        bankMessage: json['bankMessage'] as String?,
        originEvent: jsonInt(json['originEvent']),
        note:        json['note'] as String?,
        userId:      jsonInt(json['userId']),
      );

  @override
  List<Object?> get props => [
        event, kind, dtRecord, source, settledCode, paidValue, bankCode,
        bankMessage, originEvent, note, userId,
      ];
}

/// Detalhe do boleto (GET /api/bank-slips/:id) — cabeçalho + taxas
/// CONGELADAS na emissão + títulos + linha do tempo de eventos.
class BankSlipFull extends BankSlipListRow {
  const BankSlipFull({
    required super.id,
    super.ourNumber,
    super.documentNumber,
    super.dtEmission,
    super.dtExpiration,
    super.value,
    super.state,
    super.bankAccountLabel,
    super.customerName,
    super.titles,
    this.agreementId = 0,
    this.bankAccountId = 0,
    this.accept,
    this.aliqDiscount,
    this.discountValue,
    this.dtDiscountUntil,
    this.aliqInterest,
    this.aliqLate,
    this.valueLateMin,
    this.aliqFine,
    this.valueFine,
    this.valueRate,
    this.instruction,
    this.protestDays,
    this.titleRows = const [],
    this.events = const [],
  });

  final int     agreementId;
  final int     bankAccountId;
  final String? accept;
  final double? aliqDiscount;
  final double? discountValue;
  final String? dtDiscountUntil;
  final double? aliqInterest;
  final double? aliqLate;
  final double? valueLateMin;
  final double? aliqFine;
  final double? valueFine;
  final double? valueRate;
  final String? instruction;
  final int?    protestDays;
  final List<BankSlipTitleRow> titleRows;
  final List<BankSlipEventRow>    events;

  factory BankSlipFull.fromJson(Map<String, dynamic> json) {
    final row = BankSlipListRow.fromJson(json);
    return BankSlipFull(
      id:               row.id,
      ourNumber:        row.ourNumber,
      documentNumber:   row.documentNumber,
      dtEmission:       row.dtEmission,
      dtExpiration:     row.dtExpiration,
      value:            row.value,
      state:            row.state,
      bankAccountLabel: row.bankAccountLabel,
      customerName:     row.customerName,
      titles:           row.titles,
      agreementId:      jsonInt(json['agreementId']) ?? 0,
      bankAccountId:    jsonInt(json['bankAccountId']) ?? 0,
      accept:           json['accept'] as String?,
      aliqDiscount:     jsonDouble(json['aliqDiscount']),
      discountValue:    jsonDouble(json['discountValue']),
      dtDiscountUntil:  json['dtDiscountUntil'] as String?,
      aliqInterest:     jsonDouble(json['aliqInterest']),
      aliqLate:         jsonDouble(json['aliqLate']),
      valueLateMin:     jsonDouble(json['valueLateMin']),
      aliqFine:         jsonDouble(json['aliqFine']),
      valueFine:        jsonDouble(json['valueFine']),
      valueRate:        jsonDouble(json['valueRate']),
      instruction:      json['instruction'] as String?,
      protestDays:      jsonInt(json['protestDays']),
      titleRows: (json['titleRows'] as List<dynamic>? ?? [])
          .map((e) => BankSlipTitleRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      events: (json['events'] as List<dynamic>? ?? [])
          .map((e) => BankSlipEventRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [
        ...super.props,
        agreementId, bankAccountId, accept, aliqDiscount, discountValue,
        dtDiscountUntil, aliqInterest, aliqLate, valueLateMin, aliqFine,
        valueFine, valueRate, instruction, protestDays, titleRows, events,
      ];
}

/// Referência de título (PK lógica orderId+parcel) no POST de emissão.
class BankSlipTitleRef extends Equatable {
  const BankSlipTitleRef({required this.orderId, required this.parcel});

  final int orderId;
  final int parcel;

  Map<String, dynamic> toJson() => {'orderId': orderId, 'parcel': parcel};

  @override
  List<Object?> get props => [orderId, parcel];
}

/// Emissão (POST /api/bank-slips): carteira + 1..N títulos do MESMO
/// cliente (D9) + vencimento (obrigatório no agrupado; individual default
/// = vencimento do título — a API resolve quando null).
class BankSlipIssueInput extends Equatable {
  const BankSlipIssueInput({
    required this.agreementId,
    required this.titles,
    this.dtExpiration,
  });

  final int agreementId;
  final List<BankSlipTitleRef> titles;

  /// ISO 'yyyy-MM-dd'; null = default da API (só individual).
  final String? dtExpiration;

  Map<String, dynamic> toJson() => {
        'agreementId':  agreementId,
        'titles':       titles.map((t) => t.toJson()).toList(),
        'dtExpiration': dtExpiration,
      };

  @override
  List<Object?> get props => [agreementId, titles, dtExpiration];
}

/// Resultado da emissão — o nosso número vai para a SnackBar.
class BankSlipIssueResult extends Equatable {
  const BankSlipIssueResult({
    required this.id,
    this.ourNumber = '',
    this.documentNumber = '',
    this.value = 0,
    this.dtExpiration,
    this.titles = 0,
  });

  final int     id;
  final String  ourNumber;
  final String  documentNumber;
  final double  value;
  final String? dtExpiration;
  final int     titles;

  factory BankSlipIssueResult.fromJson(Map<String, dynamic> json) =>
      BankSlipIssueResult(
        id:             jsonInt(json['id']) ?? 0,
        ourNumber:      json['ourNumber']?.toString() ?? '',
        documentNumber: json['documentNumber']?.toString() ?? '',
        value:          jsonDouble(json['value']) ?? 0,
        dtExpiration:   json['dtExpiration'] as String?,
        titles:         jsonInt(json['titles']) ?? 0,
      );

  @override
  List<Object?> get props =>
      [id, ourNumber, documentNumber, value, dtExpiration, titles];
}

/// Resultado da liquidação manual (evento L — 1 baixa para N títulos
/// sob UM settled_code, D5).
class BankSlipSettleResult extends Equatable {
  const BankSlipSettleResult({
    this.settledCode = 0,
    this.statementId = 0,
    this.event = 0,
    this.titles = 0,
  });

  final int settledCode;
  final int statementId;
  final int event;
  final int titles;

  factory BankSlipSettleResult.fromJson(Map<String, dynamic> json) =>
      BankSlipSettleResult(
        settledCode: jsonInt(json['settledCode']) ?? 0,
        statementId: jsonInt(json['statementId']) ?? 0,
        event:       jsonInt(json['event']) ?? 0,
        titles:      jsonInt(json['titles']) ?? 0,
      );

  @override
  List<Object?> get props => [settledCode, statementId, event, titles];
}

/// Resultado do estorno (evento X — inverte as baixas do settled_code).
class BankSlipReverseResult extends Equatable {
  const BankSlipReverseResult({
    this.event = 0,
    this.reversed = 0,
    this.settledCode = 0,
  });

  final int event;

  /// Quantidade de baixas invertidas.
  final int reversed;
  final int settledCode;

  factory BankSlipReverseResult.fromJson(Map<String, dynamic> json) =>
      BankSlipReverseResult(
        event:       jsonInt(json['event']) ?? 0,
        reversed:    jsonInt(json['reversed']) ?? 0,
        settledCode: jsonInt(json['settledCode']) ?? 0,
      );

  @override
  List<Object?> get props => [event, reversed, settledCode];
}

/// Carteira de cobrança ATIVA (lookup /api/bank-slips/agreements — D8).
class BankSlipAgreementLookup extends Equatable {
  const BankSlipAgreementLookup({
    required this.id,
    this.agreement,
    this.bankAccountLabel,
    this.hasRange = 'N',
  });

  final int     id;
  final String? agreement;
  final String? bankAccountLabel;

  /// 'S' = carteira com faixa de nosso número (D3); 'N' = id do boleto.
  final String  hasRange;

  /// Rótulo do lookup: 'Convênio 123 · 341 - Itaú Ag 1234 CC 98765'.
  String get display => [
        if (agreement != null && agreement!.isNotEmpty) agreement!,
        if (bankAccountLabel != null && bankAccountLabel!.isNotEmpty)
          bankAccountLabel!,
      ].join(' · ');

  factory BankSlipAgreementLookup.fromJson(Map<String, dynamic> json) =>
      BankSlipAgreementLookup(
        id:               jsonInt(json['id']) ?? 0,
        agreement:        json['agreement']?.toString(),
        bankAccountLabel: json['bankAccountLabel'] as String?,
        hasRange:         json['hasRange'] as String? ?? 'N',
      );

  @override
  List<Object?> get props => [id, agreement, bankAccountLabel, hasRange];
}

/// Título a receber ABERTO sem boleto vigente (lookup
/// /api/bank-slips/open-titles) — candidato à emissão.
class BankSlipOpenTitle extends Equatable {
  const BankSlipOpenTitle({
    required this.orderId,
    required this.parcel,
    this.number,
    this.customerId,
    this.entityName,
    this.dtExpiration,
    this.balance = 0,
    this.paymentTypeDescription,
  });

  final int     orderId;
  final int     parcel;
  final String? number;
  final int?    customerId;
  final String? entityName;
  final String? dtExpiration;

  /// Saldo em aberto (derivado no servidor).
  final double  balance;
  final String? paymentTypeDescription;

  /// Identidade na seleção múltipla (PK lógica orderId+parcel).
  String get key => '$orderId-$parcel';

  BankSlipTitleRef get ref => BankSlipTitleRef(orderId: orderId, parcel: parcel);

  factory BankSlipOpenTitle.fromJson(Map<String, dynamic> json) =>
      BankSlipOpenTitle(
        orderId:      jsonInt(json['orderId']) ?? 0,
        parcel:       jsonInt(json['parcel']) ?? 0,
        number:       json['number'] as String?,
        customerId:   jsonInt(json['customerId']),
        entityName:   json['entityName'] as String?,
        dtExpiration: json['dtExpiration'] as String?,
        balance:      jsonDouble(json['balance']) ?? 0,
        paymentTypeDescription: json['paymentTypeDescription'] as String?,
      );

  @override
  List<Object?> get props => [
        orderId, parcel, number, customerId, entityName, dtExpiration,
        balance, paymentTypeDescription,
      ];
}
