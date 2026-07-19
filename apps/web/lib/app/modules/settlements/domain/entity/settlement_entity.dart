import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

/// Entidades do módulo settlements — Baixa de Títulos, Estorno e Movimento
/// (Módulo Software House, Fases 5.5/6 do 05-ORDEM-SERVICO). 2ª TELA DE
/// PROCESSO do produto: carteira de títulos em aberto com baixa em LOTE
/// (N títulos → 1 settled_code → 1 movimento), estorno IMUTÁVEL
/// (lançamento inverso status 'R' + marcação 'E' no original) e extrato
/// banco/caixa. Espelho do /api/settlements; datas em ISO 'yyyy-MM-dd'.

/// Título da carteira (GET /api/settlements/bills) — o saldo é DERIVADO
/// no servidor (tag − Σ pagos vigentes); o app nunca soma.
class SettlementBill extends Equatable {
  const SettlementBill({
    required this.orderId,
    required this.parcel,
    this.number,
    this.kind,
    this.situation,
    this.operation,
    this.stage,
    this.dtExpiration,
    this.tagValue = 0,
    this.paidValue = 0,
    this.balance = 0,
    this.entityName,
    this.paymentTypeId,
    this.paymentTypeDescription,
  });

  final int     orderId;
  final int     parcel;

  /// Nº de exibição do título (ex.: '12/1-3').
  final String? number;

  /// Natureza: 'RA'|'RM' recebimento, 'PA'|'PM' pagamento (auto/manual).
  final String? kind;

  /// 'N' normal | 'D' destinada.
  final String? situation;

  /// 'C' crédito a favor da empresa | 'D' débito contra.
  final String? operation;

  /// 'N' não enviado | 'B' finalizado em Banco | 'C' em Caixa.
  final String? stage;

  /// ISO 'yyyy-MM-dd'.
  final String? dtExpiration;
  final double  tagValue;
  final double  paidValue;

  /// Saldo em aberto (derivado no servidor — nunca negativo).
  final double  balance;
  final String? entityName;
  final int?    paymentTypeId;
  final String? paymentTypeDescription;

  /// Identidade do título na seleção múltipla (PK lógica orderId+parcel).
  String get key => '$orderId-$parcel';

  /// Vencido = dtExpiration < hoje (comparação lexicográfica de ISO).
  bool isOverdue(String todayIso) =>
      dtExpiration != null &&
      dtExpiration!.isNotEmpty &&
      dtExpiration!.compareTo(todayIso) < 0;

  factory SettlementBill.fromJson(Map<String, dynamic> json) =>
      SettlementBill(
        orderId:      jsonInt(json['orderId']) ?? 0,
        parcel:       jsonInt(json['parcel']) ?? 0,
        number:       json['number'] as String?,
        kind:         json['kind'] as String?,
        situation:    json['situation'] as String?,
        operation:    json['operation'] as String?,
        stage:        json['stage'] as String?,
        dtExpiration: json['dtExpiration'] as String?,
        tagValue:     jsonDouble(json['tagValue']) ?? 0,
        paidValue:    jsonDouble(json['paidValue']) ?? 0,
        balance:      jsonDouble(json['balance']) ?? 0,
        entityName:   json['entityName'] as String?,
        paymentTypeId: jsonInt(json['paymentTypeId']),
        paymentTypeDescription: json['paymentTypeDescription'] as String?,
      );

  @override
  List<Object?> get props => [
        orderId, parcel, number, kind, situation, operation, stage,
        dtExpiration, tagValue, paidValue, balance, entityName,
        paymentTypeId, paymentTypeDescription,
      ];
}

/// Um título dentro do LOTE de baixa — juros/multa/desconto/valor pago são
/// INFORMADOS pelo usuário (P5: cálculo automático é futuro); o líquido
/// sugerido é só o default do dialog.
class SettlementTitleInput extends Equatable {
  const SettlementTitleInput({
    required this.orderId,
    required this.parcel,
    this.interestValue = 0,
    this.lateValue = 0,
    this.discountAliquot = 0,
    required this.paidValue,
  });

  final int    orderId;
  final int    parcel;
  final double interestValue;
  final double lateValue;

  /// Desconto em % sobre o TAG do título.
  final double discountAliquot;

  /// Pode ser MENOR que o líquido — baixa parcial (o saldo é derivado).
  final double paidValue;

  Map<String, dynamic> toJson() => {
        'orderId':         orderId,
        'parcel':          parcel,
        'interestValue':   interestValue,
        'lateValue':       lateValue,
        'discountAliquot': discountAliquot,
        'paidValue':       paidValue,
      };

  @override
  List<Object?> get props =>
      [orderId, parcel, interestValue, lateValue, discountAliquot, paidValue];
}

/// Lote de baixa (POST /api/settlements): N títulos → 1 settled_code →
/// 1 movimento. Conta 0 = Caixa; planos financeiros do lote são opcionais
/// (default vem da forma de pagamento no servidor).
class SettlementBatchInput extends Equatable {
  const SettlementBatchInput({
    required this.titles,
    required this.bankAccountId,
    required this.dtPayment,
    this.dtRealPayment,
    this.financialPlanCreId,
    this.financialPlanDebId,
  });

  final List<SettlementTitleInput> titles;

  /// 0 = Caixa; > 0 = conta corrente.
  final int bankAccountId;

  /// ISO 'yyyy-MM-dd' — data prevista/lançada.
  final String dtPayment;

  /// ISO — data em que o valor efetivamente entrou/saiu (opcional).
  final String? dtRealPayment;
  final int? financialPlanCreId;
  final int? financialPlanDebId;

  Map<String, dynamic> toJson() => {
        'titles':             titles.map((t) => t.toJson()).toList(),
        'bankAccountId':      bankAccountId,
        'dtPayment':          dtPayment,
        'dtRealPayment':      dtRealPayment,
        'financialPlanCreId': financialPlanCreId,
        'financialPlanDebId': financialPlanDebId,
      };

  @override
  List<Object?> get props => [
        titles, bankAccountId, dtPayment, dtRealPayment,
        financialPlanCreId, financialPlanDebId,
      ];
}

/// Resultado da baixa em lote — o nº do código gerado vai para a SnackBar.
class SettlementBatchResult extends Equatable {
  const SettlementBatchResult({
    this.settledCode = 0,
    this.statementId = 0,
    this.totalValue = 0,
    this.titles = 0,
  });

  final int    settledCode;
  final int    statementId;
  final double totalValue;
  final int    titles;

  factory SettlementBatchResult.fromJson(Map<String, dynamic> json) =>
      SettlementBatchResult(
        settledCode: jsonInt(json['settledCode']) ?? 0,
        statementId: jsonInt(json['statementId']) ?? 0,
        totalValue:  jsonDouble(json['totalValue']) ?? 0,
        titles:      jsonInt(json['titles']) ?? 0,
      );

  @override
  List<Object?> get props => [settledCode, statementId, totalValue, titles];
}

/// Baixa registrada — linha por EVENTO da parcela (aba Baixados). Status:
/// 'N' vigente | 'E' estornada | 'R' estorno (lançamento inverso).
class SettlementSettled extends Equatable {
  const SettlementSettled({
    required this.orderId,
    required this.parcel,
    required this.event,
    this.number,
    this.kind,
    this.entityName,
    this.paidValue = 0,
    this.dtPayment,
    this.dtRealPayment,
    this.settledCode,
    this.status = 'N',
    this.originEvent,
    this.reversalReason,
  });

  final int     orderId;
  final int     parcel;
  final int     event;
  final String? number;
  final String? kind;
  final String? entityName;
  final double  paidValue;
  final String? dtPayment;
  final String? dtRealPayment;
  final int?    settledCode;
  final String  status;

  /// Evento original quando esta linha é um ESTORNO ('R').
  final int?    originEvent;
  final String? reversalReason;

  bool get isCurrent => status == 'N';

  factory SettlementSettled.fromJson(Map<String, dynamic> json) =>
      SettlementSettled(
        orderId:        jsonInt(json['orderId']) ?? 0,
        parcel:         jsonInt(json['parcel']) ?? 0,
        event:          jsonInt(json['event']) ?? 0,
        number:         json['number'] as String?,
        kind:           json['kind'] as String?,
        entityName:     json['entityName'] as String?,
        paidValue:      jsonDouble(json['paidValue']) ?? 0,
        dtPayment:      json['dtPayment'] as String?,
        dtRealPayment:  json['dtRealPayment'] as String?,
        settledCode:    jsonInt(json['settledCode']),
        status:         json['status'] as String? ?? 'N',
        originEvent:    jsonInt(json['originEvent']),
        reversalReason: json['reversalReason'] as String?,
      );

  @override
  List<Object?> get props => [
        orderId, parcel, event, number, kind, entityName, paidValue,
        dtPayment, dtRealPayment, settledCode, status, originEvent,
        reversalReason,
      ];
}

/// Resultado do estorno (POST /api/settlements/reversal).
class SettlementReversalResult extends Equatable {
  const SettlementReversalResult({
    this.reversalEvent = 0,
    this.settledCode = 0,
  });

  final int reversalEvent;

  /// Código PRÓPRIO do lançamento de estorno.
  final int settledCode;

  factory SettlementReversalResult.fromJson(Map<String, dynamic> json) =>
      SettlementReversalResult(
        reversalEvent: jsonInt(json['reversalEvent']) ?? 0,
        settledCode:   jsonInt(json['settledCode']) ?? 0,
      );

  @override
  List<Object?> get props => [reversalEvent, settledCode];
}

/// Linha do MOVIMENTO (extrato banco/caixa).
class SettlementStatementRow extends Equatable {
  const SettlementStatementRow({
    required this.id,
    this.dtRecord,
    this.bankAccountId = 0,
    this.creditValue = 0,
    this.debitValue = 0,
    this.manualHistory,
    this.settledCode,
    this.status = 'N',
    this.future,
    this.conferred,
  });

  final int     id;
  final String? dtRecord;
  final int     bankAccountId;
  final double  creditValue;
  final double  debitValue;
  final String? manualHistory;
  final int?    settledCode;

  /// 'N' vigente | 'E' estornado | 'R' lançamento de estorno.
  final String  status;
  final String? future;
  final String? conferred;

  factory SettlementStatementRow.fromJson(Map<String, dynamic> json) =>
      SettlementStatementRow(
        id:            jsonInt(json['id']) ?? 0,
        dtRecord:      json['dtRecord'] as String?,
        bankAccountId: jsonInt(json['bankAccountId']) ?? 0,
        creditValue:   jsonDouble(json['creditValue']) ?? 0,
        debitValue:    jsonDouble(json['debitValue']) ?? 0,
        manualHistory: json['manualHistory'] as String?,
        settledCode:   jsonInt(json['settledCode']),
        status:        json['status'] as String? ?? 'N',
        future:        json['future'] as String?,
        conferred:     json['conferred'] as String?,
      );

  @override
  List<Object?> get props => [
        id, dtRecord, bankAccountId, creditValue, debitValue,
        manualHistory, settledCode, status, future, conferred,
      ];
}

/// Extrato do filtro — os TOTAIS e o SALDO vêm prontos da API (o app não
/// soma; no estorno parcial o par N+R se compensa aritmeticamente).
class SettlementStatementReport extends Equatable {
  const SettlementStatementReport({
    this.rows = const [],
    this.totalCredit = 0,
    this.totalDebit = 0,
    this.balance = 0,
  });

  final List<SettlementStatementRow> rows;
  final double totalCredit;
  final double totalDebit;
  final double balance;

  factory SettlementStatementReport.fromJson(Map<String, dynamic> json) =>
      SettlementStatementReport(
        rows: (json['rows'] as List<dynamic>? ?? [])
            .map((e) =>
                SettlementStatementRow.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalCredit: jsonDouble(json['totalCredit']) ?? 0,
        totalDebit:  jsonDouble(json['totalDebit']) ?? 0,
        balance:     jsonDouble(json['balance']) ?? 0,
      );

  @override
  List<Object?> get props => [rows, totalCredit, totalDebit, balance];
}

/// Conta bancária para o lookup da baixa/movimento (GET /api/bank-accounts
/// — projeção local: módulo nunca importa módulo). A opção Caixa (id 0)
/// NÃO vem da API — a tela a oferece fixa na frente da lista.
class SettlementBankAccountLookup extends Equatable {
  const SettlementBankAccountLookup({
    required this.id,
    this.bankNumber,
    this.bankDescription,
    this.agency,
    this.agencyDv,
    this.number,
    this.numberDv,
  });

  final int     id;
  final String? bankNumber;
  final String? bankDescription;
  final String? agency;
  final String? agencyDv;
  final String? number;
  final String? numberDv;

  /// Agência com DV ('1234-5') — a página monta a exibição com i18n.
  String get agencyText {
    final a = agency ?? '';
    return (agencyDv == null || agencyDv!.isEmpty) ? a : '$a-$agencyDv';
  }

  /// Conta com DV ('98765-0').
  String get numberText {
    final n = number ?? '';
    return (numberDv == null || numberDv!.isEmpty) ? n : '$n-$numberDv';
  }

  /// Parte do banco ('341 - Itaú') — o restante ('Ag/CC') é i18n na página.
  String get bankLabel => [
        if (bankNumber != null && bankNumber!.isNotEmpty) bankNumber!,
        if (bankDescription != null && bankDescription!.isNotEmpty)
          bankDescription!,
      ].join(' - ');

  factory SettlementBankAccountLookup.fromJson(Map<String, dynamic> json) =>
      SettlementBankAccountLookup(
        id:              jsonInt(json['id']) ?? 0,
        bankNumber:      json['bankNumber'] as String?,
        bankDescription: json['bankDescription'] as String?,
        agency:          json['agency'] as String?,
        agencyDv:        json['agencyDv'] as String?,
        number:          json['number'] as String?,
        numberDv:        json['numberDv'] as String?,
      );

  @override
  List<Object?> get props =>
      [id, bankNumber, bankDescription, agency, agencyDv, number, numberDv];
}
