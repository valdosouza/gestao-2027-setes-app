import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

/// Entidades do módulo bank_accounts — Contas Bancárias (Módulo Software
/// House, seção 5.6 do prompt fechado; Valdo 2026-07-19). Espelho do
/// /api/bank-accounts: tb_bank_account no schema do cliente apontando para
/// o catálogo CENTRAL setes_central.tb_bank (FEBRABAN — DP2). Datas
/// trafegam em ISO 'yyyy-MM-dd'; a lista não traz dtOpening/phone/
/// dtContract (a edição carrega o objeto cheio via GET /:id).

/// Linha da PESQUISA (GET /api/bank-accounts) — número/descrição do banco
/// via JOIN da API no catálogo central.
class BankAccountListItem extends Equatable {
  const BankAccountListItem({
    required this.id,
    required this.bankId,
    this.bankNumber,
    this.bankDescription,
    this.agency = '',
    this.agencyDv,
    this.number = '',
    this.numberDv,
    this.manager,
    this.limitValue,
  });

  final int     id;
  final int     bankId;

  /// Código FEBRABAN do banco (JOIN da API — só exibição).
  final String? bankNumber;
  final String? bankDescription;
  final String  agency;
  final String? agencyDv;
  final String  number;
  final String? numberDv;
  final String? manager;
  final double? limitValue;

  /// Exibição do banco: "341 - Itaú Unibanco".
  String get bankDisplay {
    final n = bankNumber ?? '';
    final d = bankDescription ?? '';
    if (n.isEmpty) return d;
    return d.isEmpty ? n : '$n - $d';
  }

  /// Agência com DV quando houver: "1234-5".
  String get agencyDisplay =>
      (agencyDv == null || agencyDv!.isEmpty) ? agency : '$agency-$agencyDv';

  /// Conta com DV quando houver: "56789-0".
  String get numberDisplay =>
      (numberDv == null || numberDv!.isEmpty) ? number : '$number-$numberDv';

  factory BankAccountListItem.fromJson(Map<String, dynamic> json) =>
      BankAccountListItem(
        id:              jsonInt(json['id']) ?? 0,
        bankId:          jsonInt(json['bankId']) ?? 0,
        bankNumber:      json['bankNumber'] as String?,
        bankDescription: json['bankDescription'] as String?,
        agency:          json['agency'] as String? ?? '',
        agencyDv:        json['agencyDv'] as String?,
        number:          json['number'] as String? ?? '',
        numberDv:        json['numberDv'] as String?,
        manager:         json['manager'] as String?,
        limitValue:      jsonDouble(json['limitValue']),
      );

  @override
  List<Object?> get props => [
        id, bankId, bankNumber, bankDescription,
        agency, agencyDv, number, numberDv, manager, limitValue,
      ];
}

/// Conta COMPLETA (GET /api/bank-accounts/:id) — a lista não traz datas
/// nem telefone; a edição carrega o objeto cheio.
class BankAccountFull extends BankAccountListItem {
  const BankAccountFull({
    required super.id,
    required super.bankId,
    super.bankNumber,
    super.bankDescription,
    super.agency,
    super.agencyDv,
    super.number,
    super.numberDv,
    super.manager,
    super.limitValue,
    this.dtOpening,
    this.phone,
    this.dtContract,
  });

  /// ISO 'yyyy-MM-dd' (null = não informada).
  final String? dtOpening;
  final String? phone;

  /// ISO 'yyyy-MM-dd' (null = não informada).
  final String? dtContract;

  factory BankAccountFull.fromJson(Map<String, dynamic> json) =>
      BankAccountFull(
        id:              jsonInt(json['id']) ?? 0,
        bankId:          jsonInt(json['bankId']) ?? 0,
        bankNumber:      json['bankNumber'] as String?,
        bankDescription: json['bankDescription'] as String?,
        agency:          json['agency'] as String? ?? '',
        agencyDv:        json['agencyDv'] as String?,
        number:          json['number'] as String? ?? '',
        numberDv:        json['numberDv'] as String?,
        manager:         json['manager'] as String?,
        limitValue:      jsonDouble(json['limitValue']),
        dtOpening:       json['dtOpening'] as String?,
        phone:           json['phone'] as String?,
        dtContract:      json['dtContract'] as String?,
      );

  @override
  List<Object?> get props => [...super.props, dtOpening, phone, dtContract];
}

/// Body do POST/PUT — mesmo shape do bankAccountDto da API (Zod: agency
/// máx 8 + DV 2, number máx 10 + DV 2, phone 10, manager 25,
/// limitValue >= 0; datas 'yyyy-MM-dd' ou null).
class BankAccountInput extends Equatable {
  const BankAccountInput({
    required this.bankId,
    required this.agency,
    required this.number,
    this.dtOpening,
    this.agencyDv,
    this.numberDv,
    this.phone,
    this.manager,
    this.limitValue,
    this.dtContract,
  });

  final int     bankId;
  final String  agency;
  final String  number;
  final String? dtOpening;
  final String? agencyDv;
  final String? numberDv;
  final String? phone;
  final String? manager;
  final double? limitValue;
  final String? dtContract;

  Map<String, dynamic> toJson() => {
        'bankId':     bankId,
        'dtOpening':  dtOpening,
        'agency':     agency,
        'agencyDv':   agencyDv,
        'number':     number,
        'numberDv':   numberDv,
        'phone':      phone,
        'manager':    manager,
        'limitValue': limitValue,
        'dtContract': dtContract,
      };

  @override
  List<Object?> get props => [
        bankId, agency, number, dtOpening, agencyDv, numberDv,
        phone, manager, limitValue, dtContract,
      ];
}

/// Banco do catálogo central FEBRABAN para o lookup do form
/// (GET /api/bank-accounts/banks).
class BankLookup extends Equatable {
  const BankLookup({required this.id, this.number = '', this.description});

  final int     id;
  final String  number;
  final String? description;

  /// Exibição: "341 - Itaú Unibanco".
  String get display =>
      (description == null || description!.isEmpty)
          ? number
          : '$number - ${description!}';

  factory BankLookup.fromJson(Map<String, dynamic> json) => BankLookup(
        id:          jsonInt(json['id']) ?? 0,
        number:      json['number'] as String? ?? '',
        description: json['description'] as String?,
      );

  @override
  List<Object?> get props => [id, number, description];
}
