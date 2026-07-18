import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

import '../../../../shared/entity/domain/object_entity.dart';
import '../../../../shared/entity/domain/object_entity_fiscal.dart';

/// Linha da PESQUISA de Colaboradores (GET /api/collaborators).
class CollaboratorListItem extends Equatable {
  const CollaboratorListItem({
    required this.id,
    this.nickTrade,
    this.nameCompany,
    this.active = false,
  });

  final int     id;
  final String? nickTrade;
  final String? nameCompany;
  final bool    active;

  factory CollaboratorListItem.fromJson(Map<String, dynamic> json) =>
      CollaboratorListItem(
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
class CollaboratorPostResult extends Equatable {
  const CollaboratorPostResult({required this.id, required this.reused});

  final int  id;
  final bool reused;

  @override
  List<Object?> get props => [id, reused];
}

/// Concreta da cadeia de entidade fiscal (skill cadastro-entidade-fiscal.md):
/// ObjectEntity → ObjectEntityFiscal → ObjectCollaborator (tb_collaborator no
/// schema do cliente — PK composta id + tb_institution_id; escopo por
/// institution é da API via JWT).
///
/// Onda 2 da Entidade Única (hierarquia de papéis, decisão 16): colaborador
/// pode ser só administrativo; todo vendedor É colaborador. Mesmo desenho do
/// ObjectCustomer SEM a fatia de tributação. Datas em ISO 'yyyy-MM-dd'
/// (UI converte dd/mm/aaaa — entity_date.dart).
class ObjectCollaborator extends ObjectEntityFiscal {
  const ObjectCollaborator({
    this.id,
    this.dtAdmission,
    this.dtResignation,
    this.salary,
    this.fathersName,
    this.mothersName,
    this.voteNumber,
    this.voteZone,
    this.voteSection,
    this.militaryCertificate,
    this.pis,
    this.active = true,
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

  final String? dtAdmission;
  final String? dtResignation;
  final double? salary;
  final String? fathersName;
  final String? mothersName;
  final String? voteNumber;
  final String? voteZone;
  final String? voteSection;
  final String? militaryCertificate;
  final String? pis;
  final bool    active;

  factory ObjectCollaborator.fromJson(Map<String, dynamic> json) {
    final entity = json['entity'] as Map<String, dynamic>? ?? const {};
    return ObjectCollaborator(
      id:                  (json['id'] as num?)?.toInt(),
      dtAdmission:         json['dtAdmission'] as String?,
      dtResignation:       json['dtResignation'] as String?,
      salary:              jsonDouble(json['salary']),
      fathersName:         json['fathersName'] as String?,
      mothersName:         json['mothersName'] as String?,
      voteNumber:          json['voteNumber'] as String?,
      voteZone:            json['voteZone'] as String?,
      voteSection:         json['voteSection'] as String?,
      militaryCertificate: json['militaryCertificate'] as String?,
      pis:                 json['pis'] as String?,
      active:              (json['active'] as String?) == 'S',
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

  static String? _trimOrNull(String? value) {
    final t = value?.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  /// Body do POST/PUT (collaborators.dto.ts). NUNCA envia id/entityId no
  /// POST (decisão 9) — o id da edição vai na URL.
  Map<String, dynamic> toJson() => {
        'entity': entityToJson(),
        ...fiscalToJson(),
        'addresses':   addresses.map((a) => a.toJson()).toList(),
        'phones':      phones.map((p) => p.toJson()).toList(),
        'socialMedia': socialMedia.map((s) => s.toJson()).toList(),
        'dtAdmission':         dtAdmission,
        'dtResignation':       dtResignation,
        'salary':              salary,
        'fathersName':         _trimOrNull(fathersName),
        'mothersName':         _trimOrNull(mothersName),
        'voteNumber':          _trimOrNull(voteNumber),
        'voteZone':            _trimOrNull(voteZone),
        'voteSection':         _trimOrNull(voteSection),
        'militaryCertificate': _trimOrNull(militaryCertificate),
        'pis':                 _trimOrNull(pis),
        'active':              active ? 'S' : 'N',
      };

  /// Wrappers `Function()` nos anuláveis permitem LIMPAR (() => null).
  @override
  ObjectCollaborator copyWith({
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
    String? Function()? dtAdmission,
    String? Function()? dtResignation,
    double? Function()? salary,
    String? Function()? fathersName,
    String? Function()? mothersName,
    String? Function()? voteNumber,
    String? Function()? voteZone,
    String? Function()? voteSection,
    String? Function()? militaryCertificate,
    String? Function()? pis,
    bool? active,
  }) =>
      ObjectCollaborator(
        id:            id,
        dtAdmission:   dtAdmission != null ? dtAdmission() : this.dtAdmission,
        dtResignation:
            dtResignation != null ? dtResignation() : this.dtResignation,
        salary:        salary != null ? salary() : this.salary,
        fathersName:   fathersName != null ? fathersName() : this.fathersName,
        mothersName:   mothersName != null ? mothersName() : this.mothersName,
        voteNumber:    voteNumber != null ? voteNumber() : this.voteNumber,
        voteZone:      voteZone != null ? voteZone() : this.voteZone,
        voteSection:   voteSection != null ? voteSection() : this.voteSection,
        militaryCertificate: militaryCertificate != null
            ? militaryCertificate()
            : this.militaryCertificate,
        pis:           pis != null ? pis() : this.pis,
        active:        active ?? this.active,
        nameCompany:   nameCompany ?? this.nameCompany,
        nickTrade:     nickTrade ?? this.nickTrade,
        aniversary:    aniversary != null ? aniversary() : this.aniversary,
        addresses:     addresses ?? this.addresses,
        phones:        phones ?? this.phones,
        socialMedia:   socialMedia ?? this.socialMedia,
        personType:    personType ?? this.personType,
        person:        person ?? this.person,
        company:       company ?? this.company,
        noDoc:         noDoc ?? this.noDoc,
      );

  /// Merge da fatia editada pela EntityMainTab (aba compartilhada devolve
  /// ObjectEntityFiscal — os campos do concreto são preservados).
  ObjectCollaborator mergeFiscal(ObjectEntityFiscal fiscal) =>
      ObjectCollaborator(
        id:                  id,
        dtAdmission:         dtAdmission,
        dtResignation:       dtResignation,
        salary:              salary,
        fathersName:         fathersName,
        mothersName:         mothersName,
        voteNumber:          voteNumber,
        voteZone:            voteZone,
        voteSection:         voteSection,
        militaryCertificate: militaryCertificate,
        pis:                 pis,
        active:              active,
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
  List<Object?> get props => [
        ...super.props, id, dtAdmission, dtResignation, salary, fathersName,
        mothersName, voteNumber, voteZone, voteSection, militaryCertificate,
        pis, active,
      ];
}
