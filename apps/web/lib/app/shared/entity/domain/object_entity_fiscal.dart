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

/// Identificação SEM documento (tb_no_doc — Fase 3 Entidade Única,
/// decisões 4 e 5): terceira via do toggle fiscal. SOMENTE LEITURA no app —
/// o external_id (UUID v4 ou chave do legado via setes-sync) é gerado pelo
/// BACKEND; o toJson da cadeia nunca o envia.
class NoDocData extends Equatable {
  const NoDocData({this.externalId = ''});

  final String externalId;

  factory NoDocData.fromJson(Map<String, dynamic> json) =>
      NoDocData(externalId: json['externalId'] as String? ?? '');

  @override
  List<Object?> get props => [externalId];
}

/// ObjectEntity + toggle fiscal. Os dados dos tipos são preservados no
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
    this.noDoc,
  });

  /// 'F' (Pessoa Física → tb_person), 'J' (Pessoa Jurídica → tb_company)
  /// ou 'N' (Sem documento → tb_no_doc — Fase 3, decisão 4).
  final String personType;
  final PersonData?  person;
  final CompanyData? company;

  /// Somente leitura (o backend gera o external_id no salvar com 'N').
  final NoDocData? noDoc;

  /// Parse da cadeia fiscal completa devolvida pela API (GET :id dos
  /// concretos e GET /api/entities/by-document — mesmo shape).
  factory ObjectEntityFiscal.fromChainJson(Map<String, dynamic> json) {
    final entity = json['entity'] as Map<String, dynamic>? ?? const {};
    return ObjectEntityFiscal(
      nameCompany: entity['nameCompany'] as String? ?? '',
      nickTrade:   entity['nickTrade'] as String? ?? '',
      aniversary:  entity['aniversary'] as String?,
      personType:  json['personType'] as String? ?? 'J',
      person: json['person'] != null
          ? PersonData.fromJson(json['person'] as Map<String, dynamic>)
          : null,
      company: json['company'] != null
          ? CompanyData.fromJson(json['company'] as Map<String, dynamic>)
          : null,
      noDoc: json['noDoc'] != null
          ? NoDocData.fromJson(json['noDoc'] as Map<String, dynamic>)
          : null,
      addresses: ObjectEntity.listFromJson(
          json['addresses'], EntityAddress.fromJson),
      phones: ObjectEntity.listFromJson(json['phones'], EntityPhone.fromJson),
      socialMedia: ObjectEntity.listFromJson(
          json['socialMedia'], EntitySocialMedia.fromJson),
    );
  }

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
    NoDocData? noDoc,
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
        noDoc:       noDoc ?? this.noDoc,
      );

  /// Fatia fiscal do body (person XOR company, conforme o toggle).
  /// personType 'N' não envia NENHUMA especialização — a tb_no_doc é do
  /// backend (external_id gerado lá — Fase 3, decisão 5).
  Map<String, dynamic> fiscalToJson() => {
        'personType': personType,
        if (personType == 'F') 'person': (person ?? const PersonData()).toJson(),
        if (personType == 'J') 'company': (company ?? const CompanyData()).toJson(),
      };

  @override
  List<Object?> get props =>
      [...super.props, personType, person, company, noDoc];
}
