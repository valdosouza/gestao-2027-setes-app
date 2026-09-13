import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

/// Entidades do módulo settlement_rules — Regras de Recebimento (baixa
/// automática por forma de pagamento; prompt_contrato_financeiro_
/// baixa_automatica.md, D1–D22). Espelho do /api/settlement-rules:
/// tb_settlement_rule no schema do cliente, PK = a forma vinculada
/// (id == paymentTypeId). bankAccountId 0 = CAIXA (D1); feeRate em %;
/// paymentTerm em dias; expirationDate informativa 'yyyy-MM-dd' (D2/D11).

/// Linha da PESQUISA (GET /api/settlement-rules) — descrição da forma e
/// rótulo da conta via JOIN da API (null = caixa).
class SettlementRuleListItem extends Equatable {
  const SettlementRuleListItem({
    required this.id,
    required this.paymentTypeId,
    this.paymentTypeDescription,
    this.paymentTypeKind,
    this.bankAccountId = 0,
    this.bankAccountLabel,
    this.feeRate = 0,
    this.paymentTerm = 0,
    this.expirationDate,
  });

  /// = [paymentTypeId] (PK compartilhada com o vínculo — D2).
  final int     id;
  final int     paymentTypeId;
  final String? paymentTypeDescription;
  final String? paymentTypeKind;

  /// 0 = caixa (D1); > 0 = conta corrente da institution.
  final int     bankAccountId;

  /// "Banco ag/conta" (JOIN da API) — null quando caixa.
  final String? bankAccountLabel;
  final double  feeRate;
  final int     paymentTerm;

  /// ISO 'yyyy-MM-dd' (null = sem validade).
  final String? expirationDate;

  bool get isCashier => bankAccountId == 0;

  factory SettlementRuleListItem.fromJson(Map<String, dynamic> json) =>
      SettlementRuleListItem(
        id:                     jsonInt(json['id']) ?? 0,
        paymentTypeId:          jsonInt(json['paymentTypeId']) ?? 0,
        paymentTypeDescription: json['paymentTypeDescription'] as String?,
        paymentTypeKind:        json['paymentTypeKind'] as String?,
        bankAccountId:          jsonInt(json['bankAccountId']) ?? 0,
        bankAccountLabel:       json['bankAccountLabel'] as String?,
        feeRate:                jsonDouble(json['feeRate']) ?? 0,
        paymentTerm:            jsonInt(json['paymentTerm']) ?? 0,
        expirationDate:         json['expirationDate'] as String?,
      );

  @override
  List<Object?> get props => [
        id, paymentTypeId, paymentTypeDescription, paymentTypeKind,
        bankAccountId, bankAccountLabel, feeRate, paymentTerm, expirationDate,
      ];
}

/// Contrato COMPLETO (GET /api/settlement-rules/:id) — a lista não traz
/// a observação; a edição carrega o objeto cheio.
class SettlementRuleFull extends SettlementRuleListItem {
  const SettlementRuleFull({
    required super.id,
    required super.paymentTypeId,
    super.paymentTypeDescription,
    super.paymentTypeKind,
    super.bankAccountId,
    super.bankAccountLabel,
    super.feeRate,
    super.paymentTerm,
    super.expirationDate,
    this.note,
  });

  final String? note;

  factory SettlementRuleFull.fromJson(Map<String, dynamic> json) =>
      SettlementRuleFull(
        id:                     jsonInt(json['id']) ?? 0,
        paymentTypeId:          jsonInt(json['paymentTypeId']) ?? 0,
        paymentTypeDescription: json['paymentTypeDescription'] as String?,
        paymentTypeKind:        json['paymentTypeKind'] as String?,
        bankAccountId:          jsonInt(json['bankAccountId']) ?? 0,
        bankAccountLabel:       json['bankAccountLabel'] as String?,
        feeRate:                jsonDouble(json['feeRate']) ?? 0,
        paymentTerm:            jsonInt(json['paymentTerm']) ?? 0,
        expirationDate:         json['expirationDate'] as String?,
        note:                   json['note'] as String?,
      );

  @override
  List<Object?> get props => [...super.props, note];
}

/// Body do POST/PUT — shape dos DTOs Zod do módulo (feeRate 0..100,
/// paymentTerm inteiro 0..3650, expirationDate 'yyyy-MM-dd'|null, note máx
/// 2000). No PUT a forma NÃO viaja (é a PK — [toUpdateJson]).
class SettlementRuleInput extends Equatable {
  const SettlementRuleInput({
    required this.paymentTypeId,
    required this.bankAccountId,
    required this.feeRate,
    required this.paymentTerm,
    this.expirationDate,
    this.note,
  });

  final int     paymentTypeId;
  final int     bankAccountId;
  final double  feeRate;
  final int     paymentTerm;
  final String? expirationDate;
  final String? note;

  Map<String, dynamic> toUpdateJson() => {
        'bankAccountId':  bankAccountId,
        'feeRate':        feeRate,
        'paymentTerm':    paymentTerm,
        'expirationDate': expirationDate,
        'note':           note,
      };

  Map<String, dynamic> toJson() => {
        'paymentTypeId': paymentTypeId,
        ...toUpdateJson(),
      };

  @override
  List<Object?> get props => [
        paymentTypeId, bankAccountId, feeRate, paymentTerm,
        expirationDate, note,
      ];
}

/// Forma de pagamento vinculada + habilitada para o lookup do form
/// (GET /api/settlement-rules/payment-types). [hasContract] = já tem
/// contrato vivo (1 por forma — D2): exibida como "já contratada".
class PaymentTypeLookup extends Equatable {
  const PaymentTypeLookup({
    required this.id,
    this.description = '',
    this.kind,
    this.hasContract = false,
  });

  final int     id;
  final String  description;
  final String? kind;
  final bool    hasContract;

  factory PaymentTypeLookup.fromJson(Map<String, dynamic> json) =>
      PaymentTypeLookup(
        id:          jsonInt(json['id']) ?? 0,
        description: json['description'] as String? ?? '',
        kind:        json['kind'] as String?,
        hasContract: (json['hasContract'] as String?) == 'S',
      );

  @override
  List<Object?> get props => [id, description, kind, hasContract];
}

/// Conta corrente da institution para o lookup do destino
/// (GET /api/settlement-rules/bank-accounts).
class BankAccountLookup extends Equatable {
  const BankAccountLookup({required this.id, this.label = ''});

  final int    id;
  final String label;

  factory BankAccountLookup.fromJson(Map<String, dynamic> json) =>
      BankAccountLookup(
        id:    jsonInt(json['id']) ?? 0,
        label: json['label'] as String? ?? '',
      );

  @override
  List<Object?> get props => [id, label];
}
