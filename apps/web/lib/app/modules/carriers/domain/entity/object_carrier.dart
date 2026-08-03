import 'package:equatable/equatable.dart';

import '../../../../shared/entity/domain/entity_tax.dart';
import '../../../../shared/entity/domain/object_entity.dart';
import '../../../../shared/entity/domain/object_entity_fiscal.dart';

/// Linha da PESQUISA de Transportadoras (GET /api/carriers).
class CarrierListItem extends Equatable {
  const CarrierListItem({
    required this.id,
    this.nickTrade,
    this.nameCompany,
    this.active = false,
  });

  final int     id;
  final String? nickTrade;
  final String? nameCompany;
  final bool    active;

  factory CarrierListItem.fromJson(Map<String, dynamic> json) =>
      CarrierListItem(
        id:          (json['id'] as num).toInt(),
        nickTrade:   json['nickTrade'] as String?,
        nameCompany: json['nameCompany'] as String?,
        active:      (json['active'] as String?) == 'S',
      );

  @override
  List<Object?> get props => [id, nickTrade, nameCompany, active];
}

/// Resultado do POST: [reused] = a API reaproveitou uma entity existente
/// pelo CPF/CNPJ dentro da transação (decisões 1 e 9 da Fase 3).
class CarrierPostResult extends Equatable {
  const CarrierPostResult({required this.id, required this.reused});

  final int  id;
  final bool reused;

  @override
  List<Object?> get props => [id, reused];
}

/// Concreta da cadeia de entidade fiscal (skill cadastro-entidade-fiscal.md):
/// ObjectEntity → ObjectEntityFiscal → ObjectCarrier (tb_carrier no schema
/// do cliente — PK composta id + tb_institution_id; escopo por institution
/// é da API via JWT).
///
/// Onda 2 da Entidade Única (prompt_onda2_salesman_carrier.md): papel
/// completo de empresa externa no molde do collaborator + a aba Tributação
/// COMPARTILHADA (D2 — fatia [tax], peça shared/entity promovida do
/// customer). Campo próprio do papel: só [active].
class ObjectCarrier extends ObjectEntityFiscal {
  const ObjectCarrier({
    this.id,
    this.active = true,
    this.tax,
    super.nameCompany,
    super.nickTrade,
    super.aniversary,
    super.addresses,
    super.phones,
    super.socialMedia,
    super.personType,
    super.person,
    super.company,
    super.noDoc,
  });

  /// null = inclusão (a API cria a cadeia OU reaproveita a entity pelo doc).
  final int? id;

  final bool active;

  /// Aba Tributação (tb_entity_tax) — null no GET quando a relação ainda
  /// não tem tributação; o form SEMPRE envia (default no toJson).
  final EntityTaxData? tax;

  factory ObjectCarrier.fromJson(Map<String, dynamic> json) {
    final entity = json['entity'] as Map<String, dynamic>? ?? const {};
    return ObjectCarrier(
      id:     (json['id'] as num?)?.toInt(),
      active: (json['active'] as String?) == 'S',
      tax: json['tax'] != null
          ? EntityTaxData.fromJson(json['tax'] as Map<String, dynamic>)
          : null,
      nameCompany:  entity['nameCompany'] as String? ?? '',
      nickTrade:    entity['nickTrade'] as String? ?? '',
      aniversary:   entity['aniversary'] as String?,
      personType:   json['personType'] as String? ?? 'J',
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

  /// Body do POST/PUT (carriers.dto.ts). NUNCA envia id/entityId no POST
  /// (decisão 9) — o id da edição vai na URL. `tax` SEMPRE presente (a aba
  /// faz parte da tela — omitir significaria "não tocar" na API).
  Map<String, dynamic> toJson() => {
        'entity': entityToJson(),
        ...fiscalToJson(),
        'addresses':   addresses.map((a) => a.toJson()).toList(),
        'phones':      phones.map((p) => p.toJson()).toList(),
        'socialMedia': socialMedia.map((s) => s.toJson()).toList(),
        'active':      active ? 'S' : 'N',
        'tax':         (tax ?? const EntityTaxData()).toJson(),
      };

  @override
  ObjectCarrier copyWith({
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
    bool? active,
    EntityTaxData? tax,
  }) =>
      ObjectCarrier(
        id:           id,
        active:       active ?? this.active,
        tax:          tax ?? this.tax,
        nameCompany:  nameCompany ?? this.nameCompany,
        nickTrade:    nickTrade ?? this.nickTrade,
        aniversary:   aniversary != null ? aniversary() : this.aniversary,
        addresses:    addresses ?? this.addresses,
        phones:       phones ?? this.phones,
        socialMedia:  socialMedia ?? this.socialMedia,
        personType:   personType ?? this.personType,
        person:       person ?? this.person,
        company:      company ?? this.company,
        noDoc:        noDoc ?? this.noDoc,
      );

  /// Merge da fatia editada pela EntityMainTab (aba compartilhada devolve
  /// ObjectEntityFiscal — os campos do concreto são preservados).
  ObjectCarrier mergeFiscal(ObjectEntityFiscal fiscal) => ObjectCarrier(
        id:           id,
        active:       active,
        tax:          tax,
        nameCompany:  fiscal.nameCompany,
        nickTrade:    fiscal.nickTrade,
        aniversary:   fiscal.aniversary,
        addresses:    fiscal.addresses,
        phones:       fiscal.phones,
        socialMedia:  fiscal.socialMedia,
        personType:   fiscal.personType,
        person:       fiscal.person,
        company:      fiscal.company,
        noDoc:        fiscal.noDoc,
      );

  @override
  List<Object?> get props => [...super.props, id, active, tax];
}
