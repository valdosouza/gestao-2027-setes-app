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

/// Kinds dos eventos do boleto: E emitido · L liquidado · C cancelado ·
/// X estornado. A reserva S/G/A da D4 foi LIBERADA na Onda 2 (D-I5): a voz do
/// banco vive em tabela própria ([BankSlipRegistrationEvent]); o boleto só
/// recebe L/C com source 'A'.
abstract final class BankSlipEventKind {
  static const issued = 'E';
  static const settled = 'L';
  static const cancelled = 'C';
  static const reversed = 'X';
}

/// Kinds da VOZ DO BANCO sobre uma apresentação (Onda 2 — migration 055):
/// S enviado · G registrado · R recebido · M marcado recebido · A atrasado ·
/// P protesto · C cancelado no banco · V expirado · F falha · K cancelamento
/// solicitado por nós.
abstract final class BankSlipRegistrationKind {
  static const sent = 'S';
  static const registered = 'G';
  static const received = 'R';
  static const markedReceived = 'M';
  static const overdue = 'A';
  static const protest = 'P';
  static const cancelled = 'C';
  static const expired = 'V';
  static const failed = 'F';
  static const cancelRequested = 'K';

  /// Apresentação encerrada — o banco não dirá mais nada útil sobre ela.
  static const finals = {received, cancelled, expired, failed};
}

/// Apresentação do boleto ao banco (1 boleto × N tentativas — D16/D-I12):
/// espelho de tb_bank_slip_registration. Linha digitável/Pix são write-once
/// (chegam na consulta, nunca mudam).
class BankSlipRegistration extends Equatable {
  const BankSlipRegistration({
    required this.attempt,
    this.environment = 'S',
    this.requestCode,
    this.bankOurNumber,
    this.digitableLine,
    this.barcode,
    this.pixCopyPaste,
    this.pixTxid,
    this.createdAt,
    this.lastKind,
    this.lastBankStatus,
    this.lastDtBankStatus,
  });

  final int     attempt;
  final String  environment;
  final String? requestCode;
  final String? bankOurNumber;
  final String? digitableLine;
  final String? barcode;
  final String? pixCopyPaste;
  final String? pixTxid;
  final String? createdAt;
  final String? lastKind;
  final String? lastBankStatus;
  final String? lastDtBankStatus;

  /// Vigente = último evento NÃO final (ou envio em andamento).
  bool get isLive => !BankSlipRegistrationKind.finals.contains(lastKind ?? '');

  /// Enviado mas ainda sem código nem resposta (envio em andamento/interrompido).
  bool get inFlight => requestCode == null && lastKind == null;

  factory BankSlipRegistration.fromJson(Map<String, dynamic> json) =>
      BankSlipRegistration(
        attempt:          jsonInt(json['attempt']) ?? 0,
        environment:      json['environment'] as String? ?? 'S',
        requestCode:      json['requestCode'] as String?,
        bankOurNumber:    json['bankOurNumber'] as String?,
        digitableLine:    json['digitableLine'] as String?,
        barcode:          json['barcode'] as String?,
        pixCopyPaste:     json['pixCopyPaste'] as String?,
        pixTxid:          json['pixTxid'] as String?,
        createdAt:        json['createdAt'] as String?,
        lastKind:         json['lastKind'] as String?,
        lastBankStatus:   json['lastBankStatus'] as String?,
        lastDtBankStatus: json['lastDtBankStatus'] as String?,
      );

  @override
  List<Object?> get props => [
        attempt, environment, requestCode, bankOurNumber, digitableLine, barcode,
        pixCopyPaste, pixTxid, createdAt, lastKind, lastBankStatus, lastDtBankStatus,
      ];
}

/// Uma fala do banco sobre uma apresentação (append-only). [slipEvent] liga a
/// causa ao efeito no boleto (L/C); R sem slipEvent = efeito RECUSADO pelas
/// nossas regras — pendência que a tela precisa mostrar (D-I10).
class BankSlipRegistrationEvent extends Equatable {
  const BankSlipRegistrationEvent({
    required this.attempt,
    required this.event,
    required this.kind,
    this.bankStatus,
    this.dtBankStatus,
    this.source,
    this.paidValue,
    this.paidBy,
    this.slipEvent,
    this.message,
    this.createdAt,
  });

  final int     attempt;
  final int     event;
  final String  kind;
  final String? bankStatus;
  final String? dtBankStatus;

  /// 'W' webhook · 'Q' consulta · 'P' resposta direta ao nosso pedido.
  final String? source;
  final double? paidValue;

  /// 'B' boleto · 'X' pix.
  final String? paidBy;
  final int?    slipEvent;
  final String? message;
  final String? createdAt;

  /// RECEBIDO no banco sem liquidação aqui — a nossa regra recusou (D-I10).
  bool get effectRefused =>
      kind == BankSlipRegistrationKind.received && slipEvent == null;

  factory BankSlipRegistrationEvent.fromJson(Map<String, dynamic> json) =>
      BankSlipRegistrationEvent(
        attempt:      jsonInt(json['attempt']) ?? 0,
        event:        jsonInt(json['event']) ?? 0,
        kind:         json['kind'] as String? ?? '',
        bankStatus:   json['bankStatus'] as String?,
        dtBankStatus: json['dtBankStatus'] as String?,
        source:       json['source'] as String?,
        paidValue:    jsonDouble(json['paidValue']),
        paidBy:       json['paidBy'] as String?,
        slipEvent:    jsonInt(json['slipEvent']),
        message:      json['message'] as String?,
        createdAt:    json['createdAt'] as String?,
      );

  @override
  List<Object?> get props => [
        attempt, event, kind, bankStatus, dtBankStatus, source, paidValue, paidBy,
        slipEvent, message, createdAt,
      ];
}

/// Resultado do registro no banco (POST /:id/register).
class BankSlipRegisterResult extends Equatable {
  const BankSlipRegisterResult({required this.attempt, this.requestCode = '', this.environment = 'S'});

  final int    attempt;
  final String requestCode;
  final String environment;

  factory BankSlipRegisterResult.fromJson(Map<String, dynamic> json) =>
      BankSlipRegisterResult(
        attempt:     jsonInt(json['attempt']) ?? 0,
        requestCode: json['requestCode']?.toString() ?? '',
        environment: json['environment'] as String? ?? 'S',
      );

  @override
  List<Object?> get props => [attempt, requestCode, environment];
}

/// Resultado da consulta (POST /:id/refresh).
class BankSlipRefreshResult extends Equatable {
  const BankSlipRefreshResult({
    this.changed = false,
    this.kind,
    this.bankStatus = '',
    this.slipEvent,
    this.effectRefused,
  });

  final bool    changed;
  final String? kind;
  final String  bankStatus;
  final int?    slipEvent;
  final String? effectRefused;

  factory BankSlipRefreshResult.fromJson(Map<String, dynamic> json) =>
      BankSlipRefreshResult(
        changed:       json['changed'] == true,
        kind:          json['kind'] as String?,
        bankStatus:    json['bankStatus'] as String? ?? '',
        slipEvent:     jsonInt(json['slipEvent']),
        effectRefused: json['effectRefused'] as String?,
      );

  @override
  List<Object?> get props => [changed, kind, bankStatus, slipEvent, effectRefused];
}

/// Relatório da consulta ativa (POST /refresh).
class BankSlipBankSyncReport extends Equatable {
  const BankSlipBankSyncReport({
    this.checked = 0, this.changed = 0, this.reconciled = 0, this.errors = 0, this.stoppedEarly = false,
  });

  final int checked;
  final int changed;
  final int reconciled;
  final int errors;
  final bool stoppedEarly;

  factory BankSlipBankSyncReport.fromJson(Map<String, dynamic> json) =>
      BankSlipBankSyncReport(
        checked:      jsonInt(json['checked']) ?? 0,
        changed:      jsonInt(json['changed']) ?? 0,
        reconciled:   jsonInt(json['reconciled']) ?? 0,
        errors:       (json['errors'] as List<dynamic>?)?.length ?? 0,
        stoppedEarly: json['stoppedEarly'] == true,
      );

  @override
  List<Object?> get props => [checked, changed, reconciled, errors, stoppedEarly];
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
    this.registrations = const [],
    this.registrationEvents = const [],
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

  /// Onda 2: apresentações ao banco e a voz dele (vazias = nunca registrado).
  final List<BankSlipRegistration>      registrations;
  final List<BankSlipRegistrationEvent> registrationEvents;

  /// Última apresentação (a que a tela mostra); null = nunca registrado.
  BankSlipRegistration? get lastRegistration =>
      registrations.isEmpty ? null : registrations.last;

  /// Há apresentação VIGENTE no banco (bloqueia novo registro).
  bool get hasLiveRegistration => lastRegistration?.isLive ?? false;

  /// Pendências: falas do banco cujo efeito aqui foi recusado (D-I10).
  List<BankSlipRegistrationEvent> get refusedEffects =>
      registrationEvents.where((e) => e.effectRefused).toList();

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
      registrations: (json['registrations'] as List<dynamic>? ?? [])
          .map((e) => BankSlipRegistration.fromJson(e as Map<String, dynamic>))
          .toList(),
      registrationEvents: (json['registrationEvents'] as List<dynamic>? ?? [])
          .map((e) => BankSlipRegistrationEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [
        ...super.props,
        agreementId, bankAccountId, accept, aliqDiscount, discountValue,
        dtDiscountUntil, aliqInterest, aliqLate, valueLateMin, aliqFine,
        valueFine, valueRate, instruction, protestDays, titleRows, events,
        registrations, registrationEvents,
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
