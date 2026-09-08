import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

/// Entidades do módulo bank_charge_agreements — Carteiras de Cobrança
/// (tb_bank_charge_agreement no schema do cliente; grupo Financeiro). É a
/// contratação de cobrança com o banco: define a conta de crédito e as
/// taxas/instruções que o BOLETO (módulo bank_slips) CONGELA na emissão.
/// Espelho do /api/bank-charge-agreements. Taxas em % (0–100); demais
/// valores monetários (>= 0); `dayProtest` só é exigido quando
/// `protest == 'S'` (regra do backend — DTO Zod com refine).

/// Linha da PESQUISA (GET /api/bank-charge-agreements) — rótulo da conta
/// corrente via JOIN da API.
class BankChargeAgreementListItem extends Equatable {
  const BankChargeAgreementListItem({
    required this.id,
    required this.agreement,
    required this.bankAccountId,
    this.bankAccountLabel,
    this.active = 'S',
    this.ourNumberNext,
  });

  final int     id;
  final String  agreement;
  final int     bankAccountId;

  /// "Banco — agência/conta" (JOIN da API).
  final String? bankAccountLabel;

  /// 'S'/'N' — decide se a carteira entra no gate 0/1/n do faturamento
  /// automático de boletos.
  final String  active;

  /// Próximo nosso número da faixa (null = o boleto usa o próprio id).
  final int?    ourNumberNext;

  String get bankAccountDisplay => bankAccountLabel ?? '';

  factory BankChargeAgreementListItem.fromJson(Map<String, dynamic> json) =>
      BankChargeAgreementListItem(
        id:               jsonInt(json['id']) ?? 0,
        agreement:        json['agreement'] as String? ?? '',
        bankAccountId:    jsonInt(json['bankAccountId']) ?? 0,
        bankAccountLabel: json['bankAccountLabel'] as String?,
        active:           json['active'] as String? ?? 'S',
        ourNumberNext:    jsonInt(json['ourNumberNext']),
      );

  @override
  List<Object?> get props =>
      [id, agreement, bankAccountId, bankAccountLabel, active, ourNumberNext];
}

/// Carteira COMPLETA (GET /api/bank-charge-agreements/:id) — a lista não
/// traz encargos/instrução/protesto; a edição carrega o objeto cheio.
class BankChargeAgreementFull extends BankChargeAgreementListItem {
  const BankChargeAgreementFull({
    required super.id,
    required super.agreement,
    required super.bankAccountId,
    super.bankAccountLabel,
    super.active,
    super.ourNumberNext,
    this.accept = 'N',
    this.aliqDiscount,
    this.aliqInterest,
    this.aliqLate,
    this.valueLateMin,
    this.aliqFine,
    this.valueFine,
    this.valueRate,
    this.instruction,
    this.protest = 'N',
    this.dayProtest,
  });

  final String  accept;
  final double? aliqDiscount;
  final double? aliqInterest;
  final double? aliqLate;
  final double? valueLateMin;
  final double? aliqFine;
  final double? valueFine;
  final double? valueRate;
  final String? instruction;
  final String  protest;
  final int?    dayProtest;

  factory BankChargeAgreementFull.fromJson(Map<String, dynamic> json) =>
      BankChargeAgreementFull(
        id:               jsonInt(json['id']) ?? 0,
        agreement:        json['agreement'] as String? ?? '',
        bankAccountId:    jsonInt(json['bankAccountId']) ?? 0,
        bankAccountLabel: json['bankAccountLabel'] as String?,
        active:           json['active'] as String? ?? 'S',
        ourNumberNext:    jsonInt(json['ourNumberNext']),
        accept:           json['accept'] as String? ?? 'N',
        aliqDiscount:     jsonDouble(json['aliqDiscount']),
        aliqInterest:     jsonDouble(json['aliqInterest']),
        aliqLate:         jsonDouble(json['aliqLate']),
        valueLateMin:     jsonDouble(json['valueLateMin']),
        aliqFine:         jsonDouble(json['aliqFine']),
        valueFine:        jsonDouble(json['valueFine']),
        valueRate:        jsonDouble(json['valueRate']),
        instruction:      json['instruction'] as String?,
        protest:          json['protest'] as String? ?? 'N',
        dayProtest:       jsonInt(json['dayProtest']),
      );

  @override
  List<Object?> get props => [
        ...super.props,
        accept, aliqDiscount, aliqInterest, aliqLate, valueLateMin,
        aliqFine, valueFine, valueRate, instruction, protest, dayProtest,
      ];
}

/// Body do POST/PUT — mesmo shape do chargeAgreementDto da API (agreement
/// máx 30, taxas 0..100, valores >= 0, instruction máx 500, dayProtest
/// obrigatório quando protest == 'S', ourNumberNext positivo).
class BankChargeAgreementInput extends Equatable {
  const BankChargeAgreementInput({
    required this.agreement,
    required this.bankAccountId,
    required this.active,
    required this.accept,
    required this.protest,
    this.aliqDiscount,
    this.aliqInterest,
    this.aliqLate,
    this.valueLateMin,
    this.aliqFine,
    this.valueFine,
    this.valueRate,
    this.instruction,
    this.dayProtest,
    this.ourNumberNext,
  });

  final String  agreement;
  final int     bankAccountId;
  final String  active;
  final String  accept;
  final String  protest;
  final double? aliqDiscount;
  final double? aliqInterest;
  final double? aliqLate;
  final double? valueLateMin;
  final double? aliqFine;
  final double? valueFine;
  final double? valueRate;
  final String? instruction;
  final int?    dayProtest;
  final int?    ourNumberNext;

  Map<String, dynamic> toJson() => {
        'agreement':     agreement,
        'bankAccountId': bankAccountId,
        'active':        active,
        'accept':        accept,
        'aliqDiscount':  aliqDiscount,
        'aliqInterest':  aliqInterest,
        'aliqLate':      aliqLate,
        'valueLateMin':  valueLateMin,
        'aliqFine':      aliqFine,
        'valueFine':     valueFine,
        'valueRate':     valueRate,
        'instruction':   instruction,
        'protest':       protest,
        'dayProtest':    dayProtest,
        'ourNumberNext': ourNumberNext,
      };

  @override
  List<Object?> get props => [
        agreement, bankAccountId, active, accept, aliqDiscount, aliqInterest,
        aliqLate, valueLateMin, aliqFine, valueFine, valueRate, instruction,
        protest, dayProtest, ourNumberNext,
      ];
}

/// Conta corrente da institution para o lookup DEDICADO do form
/// (GET /api/bank-charge-agreements/bank-accounts — {id, label}).
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
