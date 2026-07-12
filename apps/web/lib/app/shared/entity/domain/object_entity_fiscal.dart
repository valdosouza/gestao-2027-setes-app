import 'package:equatable/equatable.dart';

import 'object_entity.dart';

/// Especialização fiscal da cadeia (skill cadastro-entidade-fiscal.md):
/// PF×PJ é TOGGLE — preenche tb_person OU tb_company conforme [personType].
/// Na edição, trocar o tipo vira soft delete da especialização antiga +
/// upsert da nova (feito pela API na transação única).

/// Dados de Pessoa Física (tb_person).
class PersonData extends Equatable {
  const PersonData({this.cpf = '', this.rg, this.birthday});

  final String  cpf;
  final String? rg;

  /// ISO 'yyyy-MM-dd'.
  final String? birthday;

  factory PersonData.fromJson(Map<String, dynamic> json) => PersonData(
        cpf:      json['cpf'] as String? ?? '',
        rg:       json['rg'] as String?,
        birthday: json['birthday'] as String?,
      );

  /// CPF só com dígitos (o usuário pode digitar pontos/traço).
  String get cpfDigits => cpf.replaceAll(RegExp(r'\D'), '');

  Map<String, dynamic> toJson() => {
        'cpf': cpfDigits,
        if (rg != null && rg!.isNotEmpty) 'rg': rg,
        if (birthday != null) 'birthday': birthday,
      };

  /// [birthday] usa wrapper para permitir LIMPAR a data (() => null).
  PersonData copyWith({String? cpf, String? rg, String? Function()? birthday}) =>
      PersonData(
        cpf:      cpf ?? this.cpf,
        rg:       rg ?? this.rg,
        birthday: birthday != null ? birthday() : this.birthday,
      );

  @override
  List<Object?> get props => [cpf, rg, birthday];
}

/// Dados de Pessoa Jurídica (tb_company).
class CompanyData extends Equatable {
  const CompanyData({this.cnpj = '', this.ie, this.im, this.dtFoundation});

  final String  cnpj;
  final String? ie;
  final String? im;

  /// ISO 'yyyy-MM-dd'.
  final String? dtFoundation;

  factory CompanyData.fromJson(Map<String, dynamic> json) => CompanyData(
        cnpj:         json['cnpj'] as String? ?? '',
        ie:           json['ie'] as String?,
        im:           json['im'] as String?,
        dtFoundation: json['dtFoundation'] as String?,
      );

  /// CNPJ só com dígitos (o usuário pode digitar pontos/barra/traço).
  String get cnpjDigits => cnpj.replaceAll(RegExp(r'\D'), '');

  Map<String, dynamic> toJson() => {
        'cnpj': cnpjDigits,
        if (ie != null && ie!.isNotEmpty) 'ie': ie,
        if (im != null && im!.isNotEmpty) 'im': im,
        if (dtFoundation != null) 'dtFoundation': dtFoundation,
      };

  /// [dtFoundation] usa wrapper para permitir LIMPAR a data (() => null).
  CompanyData copyWith(
          {String? cnpj, String? ie, String? im, String? Function()? dtFoundation}) =>
      CompanyData(
        cnpj:         cnpj ?? this.cnpj,
        ie:           ie ?? this.ie,
        im:           im ?? this.im,
        dtFoundation: dtFoundation != null ? dtFoundation() : this.dtFoundation,
      );

  @override
  List<Object?> get props => [cnpj, ie, im, dtFoundation];
}

/// ObjectEntity + toggle fiscal. Os dados dos DOIS tipos são preservados no
/// draft (trocar o toggle não apaga o que foi digitado); apenas a fatia do
/// [personType] atual é enviada no salvar (fiscalToJson).
class ObjectEntityFiscal extends ObjectEntity {
  const ObjectEntityFiscal({
    super.nameCompany,
    super.nickTrade,
    super.aniversary,
    super.addresses,
    super.phones,
    super.socialMedia,
    this.personType = 'J',
    this.person,
    this.company,
  });

  /// 'F' (Pessoa Física → tb_person) ou 'J' (Pessoa Jurídica → tb_company).
  final String personType;
  final PersonData?  person;
  final CompanyData? company;

  ObjectEntityFiscal copyWith({
    String? nameCompany,
    String? nickTrade,
    String? Function()? aniversary,
    List<EntityAddress>? addresses,
    List<EntityPhone>? phones,
    List<EntitySocialMedia>? socialMedia,
    String? personType,
    PersonData? person,
    CompanyData? company,
  }) =>
      ObjectEntityFiscal(
        nameCompany: nameCompany ?? this.nameCompany,
        nickTrade:   nickTrade ?? this.nickTrade,
        aniversary:  aniversary != null ? aniversary() : this.aniversary,
        addresses:   addresses ?? this.addresses,
        phones:      phones ?? this.phones,
        socialMedia: socialMedia ?? this.socialMedia,
        personType:  personType ?? this.personType,
        person:      person ?? this.person,
        company:     company ?? this.company,
      );

  /// Fatia fiscal do body (person XOR company, conforme o toggle).
  Map<String, dynamic> fiscalToJson() => {
        'personType': personType,
        if (personType == 'F') 'person': (person ?? const PersonData()).toJson(),
        if (personType == 'J') 'company': (company ?? const CompanyData()).toJson(),
      };

  @override
  List<Object?> get props => [...super.props, personType, person, company];
}
