import 'package:equatable/equatable.dart';

import '../../../../shared/entity/domain/object_entity.dart';

/// tb_institution do PRÓPRIO estabelecimento do usuário logado — módulo
/// `establishment` (menu "Meu Estabelecimento"). Cardinalidade 1 garantida
/// pela API via token (institutionId implícito): NUNCA existe `:id` na URL
/// e a tela NUNCA passa por lista (parecer setes-conceito, 2026-08-25).
///
/// Reaproveita as MESMAS listas de apoio da cadeia de entidade fiscal
/// (EntityAddress/EntityPhone/EntitySocialMedia de shared/entity) — só o
/// subconjunto de campos é restrito (decisão fechada com o usuário):
/// document/personType são SOMENTE EXIBIÇÃO (nunca viajam no PUT).
class ObjectEstablishment extends Equatable {
  const ObjectEstablishment({
    this.nameCompany = '',
    this.nickTrade = '',
    this.document = '',
    this.personType = 'J',
    this.ie,
    this.im,
    this.taxRegime,
    this.addresses = const [],
    this.phones = const [],
    this.socialMedia = const [],
  });

  final String nameCompany;
  final String nickTrade;

  /// CPF/CNPJ — SOMENTE EXIBIÇÃO (desabilitado na tela, nunca enviado).
  final String document;

  /// 'F' | 'J' — SOMENTE EXIBIÇÃO.
  final String personType;

  final String? ie;
  final String? im;

  /// Regime tributário do estabelecimento (D39 — campo avulso, mantido SÓ
  /// aqui): rótulo canônico da API (TAX_REGIMES) — não se traduz.
  final String? taxRegime;

  final List<EntityAddress> addresses;
  final List<EntityPhone> phones;
  final List<EntitySocialMedia> socialMedia;

  factory ObjectEstablishment.fromJson(Map<String, dynamic> json) =>
      ObjectEstablishment(
        nameCompany: json['nameCompany'] as String? ?? '',
        nickTrade:   json['nickTrade'] as String? ?? '',
        document:    json['document'] as String? ?? '',
        personType:  json['personType'] as String? ?? 'J',
        ie:          json['ie'] as String?,
        im:          json['im'] as String?,
        taxRegime:   json['taxRegime'] as String?,
        addresses: ObjectEntity.listFromJson(
            json['addresses'], EntityAddress.fromJson),
        phones: ObjectEntity.listFromJson(json['phones'], EntityPhone.fromJson),
        // Contrato da API usa "socials" (EstablishmentDto.socials).
        socialMedia: ObjectEntity.listFromJson(
            json['socials'], EntitySocialMedia.fromJson),
      );

  /// Body do PUT (EstablishmentUpdateDto) — SEM document/personType.
  Map<String, dynamic> toJson() => {
        'nameCompany': nameCompany.trim(),
        'nickTrade':   nickTrade.trim(),
        if (ie != null && ie!.trim().isNotEmpty) 'ie': ie!.trim(),
        if (im != null && im!.trim().isNotEmpty) 'im': im!.trim(),
        // Sempre viaja (null = sem regime): o draft nasce do GET, então
        // reenviar o valor corrente é idempotente.
        'taxRegime':   taxRegime,
        'addresses':   addresses.map((a) => a.toJson()).toList(),
        'phones':      phones.map((p) => p.toJson()).toList(),
        'socials':     socialMedia.map((s) => s.toJson()).toList(),
      };

  ObjectEstablishment copyWith({
    String? nameCompany,
    String? nickTrade,
    String? ie,
    String? im,
    String? taxRegime,
    List<EntityAddress>? addresses,
    List<EntityPhone>? phones,
    List<EntitySocialMedia>? socialMedia,
  }) =>
      ObjectEstablishment(
        nameCompany: nameCompany ?? this.nameCompany,
        nickTrade:   nickTrade ?? this.nickTrade,
        document:    document,
        personType:  personType,
        ie:          ie ?? this.ie,
        im:          im ?? this.im,
        taxRegime:   taxRegime ?? this.taxRegime,
        addresses:   addresses ?? this.addresses,
        phones:      phones ?? this.phones,
        socialMedia: socialMedia ?? this.socialMedia,
      );

  @override
  List<Object?> get props => [
        nameCompany, nickTrade, document, personType, ie, im, taxRegime,
        addresses, phones, socialMedia,
      ];
}
