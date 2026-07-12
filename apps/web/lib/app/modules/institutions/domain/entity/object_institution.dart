import 'package:equatable/equatable.dart';

import '../../../../shared/entity/domain/object_entity.dart';
import '../../../../shared/entity/domain/object_entity_fiscal.dart';

/// Linha da PESQUISA de Estabelecimentos (GET /api/institutions).
class InstitutionListItem extends Equatable {
  const InstitutionListItem({
    required this.id,
    this.nickTrade,
    this.nameCompany,
    required this.schemaName,
    this.active = false,
  });

  final int     id;
  final String? nickTrade;
  final String? nameCompany;
  final String  schemaName;
  final bool    active;

  factory InstitutionListItem.fromJson(Map<String, dynamic> json) =>
      InstitutionListItem(
        id:          (json['id'] as num).toInt(),
        nickTrade:   json['nickTrade'] as String?,
        nameCompany: json['nameCompany'] as String?,
        schemaName:  json['schemaName'] as String? ?? '',
        active:      (json['active'] as String?) == 'S',
      );

  @override
  List<Object?> get props => [id, nickTrade, nameCompany, schemaName, active];
}

/// Concreta da cadeia de entidade fiscal (skill cadastro-entidade-fiscal.md):
/// ObjectEntity → ObjectEntityFiscal → ObjectInstitution (tb_institution).
///
/// schema_name: padrão `setes_<nome>`, informado na inclusão e IMUTÁVEL na
/// edição. [active]: quem ativa na inclusão é a migração do schema (backend).
class ObjectInstitution extends ObjectEntityFiscal {
  const ObjectInstitution({
    this.id,
    this.schemaName = '',
    this.active = false,
    super.nameCompany,
    super.nickTrade,
    super.aniversary,
    super.addresses,
    super.phones,
    super.socialMedia,
    super.personType,
    super.person,
    super.company,
  });

  /// null = inclusão (id nasce MAX+1 de tb_entity no backend).
  final int?   id;
  final String schemaName;
  final bool   active;

  factory ObjectInstitution.fromJson(Map<String, dynamic> json) {
    final entity = json['entity'] as Map<String, dynamic>? ?? const {};
    return ObjectInstitution(
      id:          (json['id'] as num?)?.toInt(),
      schemaName:  json['schemaName'] as String? ?? '',
      active:      (json['active'] as String?) == 'S',
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
      addresses: ObjectEntity.listFromJson(
          json['addresses'], EntityAddress.fromJson),
      phones: ObjectEntity.listFromJson(json['phones'], EntityPhone.fromJson),
      socialMedia: ObjectEntity.listFromJson(
          json['socialMedia'], EntitySocialMedia.fromJson),
    );
  }

  /// Body do POST/PUT (institutions.dto.ts). schemaName só vai na INCLUSÃO
  /// (imutável na edição); active só vai na EDIÇÃO (na inclusão quem ativa
  /// é a migração do schema).
  Map<String, dynamic> toJson({required bool creating}) => {
        'entity': entityToJson(),
        ...fiscalToJson(),
        'addresses':   addresses.map((a) => a.toJson()).toList(),
        'phones':      phones.map((p) => p.toJson()).toList(),
        'socialMedia': socialMedia.map((s) => s.toJson()).toList(),
        if (creating) 'schemaName': schemaName.trim(),
        if (!creating) 'active': active ? 'S' : 'N',
      };

  @override
  ObjectInstitution copyWith({
    String? nameCompany,
    String? nickTrade,
    String? Function()? aniversary,
    List<EntityAddress>? addresses,
    List<EntityPhone>? phones,
    List<EntitySocialMedia>? socialMedia,
    String? personType,
    PersonData? person,
    CompanyData? company,
    String? schemaName,
    bool? active,
  }) =>
      ObjectInstitution(
        id:          id,
        schemaName:  schemaName ?? this.schemaName,
        active:      active ?? this.active,
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

  /// Merge da fatia editada pela EntityMainTab (aba compartilhada devolve
  /// ObjectEntityFiscal — os campos do concreto são preservados).
  ObjectInstitution mergeFiscal(ObjectEntityFiscal fiscal) =>
      ObjectInstitution(
        id:          id,
        schemaName:  schemaName,
        active:      active,
        nameCompany: fiscal.nameCompany,
        nickTrade:   fiscal.nickTrade,
        aniversary:  fiscal.aniversary,
        addresses:   fiscal.addresses,
        phones:      fiscal.phones,
        socialMedia: fiscal.socialMedia,
        personType:  fiscal.personType,
        person:      fiscal.person,
        company:     fiscal.company,
      );

  @override
  List<Object?> get props => [...super.props, id, schemaName, active];
}
