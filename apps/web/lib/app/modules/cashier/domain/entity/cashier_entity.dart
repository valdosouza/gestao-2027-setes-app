import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

/// Entidades do módulo cashier — Abertura/Fechamento de Caixa (W3.2,
/// parecer setes-conceito 2026-08-22). 4ª TELA DE PROCESSO do produto —
/// mas de SESSÃO, não de lista: 1 sessão por dia+usuário (terminal fixo 0
/// pro caixa web — Q-Caixa 5). Espelho do /api/cashier; saldo e diferenças
/// são sempre DERIVADOS no servidor (o app nunca soma).

/// Sessão de caixa (GET /current, POST /open) — `hrEnd` null = ABERTA.
class CashierRow extends Equatable {
  const CashierRow({
    required this.id,
    this.dtRecord,
    this.userId = 0,
    this.hrBegin,
    this.hrEnd,
  });

  final int id;

  /// ISO 'yyyy-MM-dd'.
  final String? dtRecord;
  final int userId;

  /// 'HH:mm:ss'.
  final String? hrBegin;

  /// null = sessão ABERTA.
  final String? hrEnd;

  bool get isOpen => hrEnd == null || hrEnd!.isEmpty;

  factory CashierRow.fromJson(Map<String, dynamic> json) => CashierRow(
        id:       jsonInt(json['id']) ?? 0,
        dtRecord: json['dtRecord'] as String?,
        userId:   jsonInt(json['userId']) ?? 0,
        hrBegin:  json['hrBegin'] as String?,
        hrEnd:    json['hrEnd'] as String?,
      );

  @override
  List<Object?> get props => [id, dtRecord, userId, hrBegin, hrEnd];
}

/// Linha do saldo REGISTRADO por forma de pagamento (dentro do detalhe).
class CashierPaymentTypeBalance extends Equatable {
  const CashierPaymentTypeBalance({
    required this.paymentTypeId,
    this.paymentTypeDescription,
    this.value = 0,
  });

  final int paymentTypeId;
  final String? paymentTypeDescription;
  final double value;

  factory CashierPaymentTypeBalance.fromJson(Map<String, dynamic> json) =>
      CashierPaymentTypeBalance(
        paymentTypeId: jsonInt(json['paymentTypeId']) ?? 0,
        paymentTypeDescription: json['paymentTypeDescription'] as String?,
        value: jsonDouble(json['value']) ?? 0,
      );

  @override
  List<Object?> get props => [paymentTypeId, paymentTypeDescription, value];
}

/// Detalhe da sessão (GET /:id) — [balance] SEMPRE derivado no servidor.
class CashierDetail extends Equatable {
  const CashierDetail({
    required this.cashier,
    this.balance = 0,
    this.registeredByPaymentType = const [],
  });

  final CashierRow cashier;
  final double balance;
  final List<CashierPaymentTypeBalance> registeredByPaymentType;

  factory CashierDetail.fromJson(Map<String, dynamic> json) => CashierDetail(
        cashier: CashierRow.fromJson(
            json['cashier'] as Map<String, dynamic>? ?? const {}),
        balance: jsonDouble(json['balance']) ?? 0,
        registeredByPaymentType:
            (json['registeredByPaymentType'] as List<dynamic>? ?? [])
                .map((e) => CashierPaymentTypeBalance.fromJson(
                    e as Map<String, dynamic>))
                .toList(),
      );

  @override
  List<Object?> get props => [cashier, balance, registeredByPaymentType];
}

/// Body do POST /:id/withdraw — sem [destinationBankAccountId] = retirada
/// simples; com = transferência (crédito espelhado na conta destino).
class CashierWithdrawInput extends Equatable {
  const CashierWithdrawInput({
    required this.value,
    required this.history,
    this.destinationBankAccountId,
  });

  final double value;
  final String history;
  final int? destinationBankAccountId;

  Map<String, dynamic> toJson() => {
        'value':                    value,
        'history':                  history,
        'destinationBankAccountId': destinationBankAccountId,
      };

  @override
  List<Object?> get props => [value, history, destinationBankAccountId];
}

/// Resultado da retirada/transferência.
class CashierWithdrawResult extends Equatable {
  const CashierWithdrawResult({
    this.statementId = 0,
    this.destinationStatementId,
  });

  final int statementId;

  /// null = retirada simples (sem transferência).
  final int? destinationStatementId;

  factory CashierWithdrawResult.fromJson(Map<String, dynamic> json) =>
      CashierWithdrawResult(
        statementId: jsonInt(json['statementId']) ?? 0,
        destinationStatementId: jsonInt(json['destinationStatementId']),
      );

  @override
  List<Object?> get props => [statementId, destinationStatementId];
}

/// Item digitado no dialog de fechamento — conferência POR FORMA.
class CashierCloseItemInput extends Equatable {
  const CashierCloseItemInput({
    required this.paymentTypeId,
    required this.countedValue,
  });

  final int paymentTypeId;
  final double countedValue;

  Map<String, dynamic> toJson() => {
        'paymentTypeId': paymentTypeId,
        'countedValue':  countedValue,
      };

  @override
  List<Object?> get props => [paymentTypeId, countedValue];
}

/// Body do POST /:id/close.
class CashierCloseInput extends Equatable {
  const CashierCloseInput({
    required this.items,
    this.transferBankAccountId,
  });

  final List<CashierCloseItemInput> items;
  final int? transferBankAccountId;

  Map<String, dynamic> toJson() => {
        'items': items.map((i) => i.toJson()).toList(),
        'transferBankAccountId': transferBankAccountId,
      };

  @override
  List<Object?> get props => [items, transferBankAccountId];
}

/// Linha do RELATÓRIO de fechamento — registrado × contado × diferença
/// (Q-Caixa 3: a diferença é só AUDITORIA, nunca bloqueia).
class CashierCloseReportItem extends Equatable {
  const CashierCloseReportItem({
    required this.paymentTypeId,
    this.paymentTypeDescription,
    this.registeredValue = 0,
    this.countedValue = 0,
    this.difference = 0,
  });

  final int paymentTypeId;
  final String? paymentTypeDescription;
  final double registeredValue;
  final double countedValue;
  final double difference;

  factory CashierCloseReportItem.fromJson(Map<String, dynamic> json) =>
      CashierCloseReportItem(
        paymentTypeId: jsonInt(json['paymentTypeId']) ?? 0,
        paymentTypeDescription: json['paymentTypeDescription'] as String?,
        registeredValue: jsonDouble(json['registeredValue']) ?? 0,
        countedValue:    jsonDouble(json['countedValue']) ?? 0,
        difference:      jsonDouble(json['difference']) ?? 0,
      );

  @override
  List<Object?> get props =>
      [paymentTypeId, paymentTypeDescription, registeredValue, countedValue, difference];
}

/// Resultado do fechamento — o RELATÓRIO completo é mostrado num dialog
/// de resultado (nunca só um "ok" — mentalidade ERP: nada silencioso).
class CashierCloseResult extends Equatable {
  const CashierCloseResult({
    this.cashierId = 0,
    this.hrEnd,
    this.items = const [],
    this.transfer,
  });

  final int cashierId;
  final String? hrEnd;
  final List<CashierCloseReportItem> items;

  /// Transferência do saldo total ao fechar (null = não pedida).
  final CashierWithdrawResult? transfer;

  factory CashierCloseResult.fromJson(Map<String, dynamic> json) =>
      CashierCloseResult(
        cashierId: jsonInt(json['cashierId']) ?? 0,
        hrEnd:     json['hrEnd'] as String?,
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) =>
                CashierCloseReportItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        transfer: json['transfer'] == null
            ? null
            : CashierWithdrawResult.fromJson(
                json['transfer'] as Map<String, dynamic>),
      );

  @override
  List<Object?> get props => [cashierId, hrEnd, items, transfer];
}

/// Conta bancária para o lookup OPCIONAL de retirada/transferência
/// (GET /api/bank-accounts — projeção local: módulo nunca importa módulo).
class CashierBankAccountLookup extends Equatable {
  const CashierBankAccountLookup({
    required this.id,
    this.bankNumber,
    this.bankDescription,
    this.agency,
    this.agencyDv,
    this.number,
    this.numberDv,
  });

  final int id;
  final String? bankNumber;
  final String? bankDescription;
  final String? agency;
  final String? agencyDv;
  final String? number;
  final String? numberDv;

  /// Agência com DV ('1234-5').
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

  factory CashierBankAccountLookup.fromJson(Map<String, dynamic> json) =>
      CashierBankAccountLookup(
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
