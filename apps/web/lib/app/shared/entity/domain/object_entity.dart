import 'package:equatable/equatable.dart';

/// Cadeia de entidade fiscal — camada base (skill cadastro-entidade-fiscal.md).
///
/// Vive em app/shared/entity porque é usada por 5+ módulos (Institution,
/// Customer, Provider, Collaborator, Bank — regra de promoção da
/// ARQUITETURA_MODULOS.md). PROIBIDO importar qualquer coisa de módulo
/// concreto (grep de módulos dentro de shared/entity deve voltar vazio).
///
/// Datas trafegam como String ISO 'yyyy-MM-dd' (contrato da setes-api).

/// Endereço da entidade (tb_address — PK id+kind: "vários" = vários kinds).
class EntityAddress extends Equatable {
  const EntityAddress({
    required this.kind,
    required this.street,
    this.nmbr,
    this.complement,
    this.neighborhood,
    this.zipCode,
    required this.tbCountryId,
    required this.tbStateId,
    required this.tbCityId,
    this.main = true,
    this.countryName,
    this.stateName,
    this.cityName,
  });

  final String  kind;
  final String  street;
  final String? nmbr;
  final String? complement;
  final String? neighborhood;
  final String? zipCode;
  final int     tbCountryId;
  final int     tbStateId;
  final int     tbCityId;
  final bool    main;

  /// Nomes via JOIN da API — exibição (campo-lookup-fk.md); nunca enviados.
  final String? countryName;
  final String? stateName;
  final String? cityName;

  factory EntityAddress.fromJson(Map<String, dynamic> json) => EntityAddress(
        kind:         json['kind'] as String? ?? '',
        street:       json['street'] as String? ?? '',
        nmbr:         json['nmbr'] as String?,
        complement:   json['complement'] as String?,
        neighborhood: json['neighborhood'] as String?,
        zipCode:      json['zipCode'] as String?,
        tbCountryId:  (json['tbCountryId'] as num?)?.toInt() ?? 0,
        tbStateId:    (json['tbStateId'] as num?)?.toInt() ?? 0,
        tbCityId:     (json['tbCityId'] as num?)?.toInt() ?? 0,
        main:         (json['main'] as String?) != 'N',
        countryName:  json['countryName'] as String?,
        stateName:    json['stateName'] as String?,
        cityName:     json['cityName'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'kind':         kind,
        'street':       street,
        if (nmbr != null && nmbr!.isNotEmpty) 'nmbr': nmbr,
        if (complement != null && complement!.isNotEmpty) 'complement': complement,
        if (neighborhood != null && neighborhood!.isNotEmpty) 'neighborhood': neighborhood,
        if (zipCode != null && zipCode!.isNotEmpty) 'zipCode': zipCode,
        'tbCountryId':  tbCountryId,
        'tbStateId':    tbStateId,
        'tbCityId':     tbCityId,
        'main':         main ? 'S' : 'N',
      };

  @override
  List<Object?> get props => [
        kind, street, nmbr, complement, neighborhood, zipCode,
        tbCountryId, tbStateId, tbCityId, main,
        countryName, stateName, cityName,
      ];
}

/// Fone da entidade (tb_phone — SINGULAR; PK id+kind).
class EntityPhone extends Equatable {
  const EntityPhone({required this.kind, this.contact, this.number});

  final String  kind;
  final String? contact;
  final String? number;

  factory EntityPhone.fromJson(Map<String, dynamic> json) => EntityPhone(
        kind:    json['kind'] as String? ?? '',
        contact: json['contact'] as String?,
        number:  json['number'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'kind': kind,
        if (contact != null && contact!.isNotEmpty) 'contact': contact,
        if (number != null && number!.isNotEmpty) 'number': number,
      };

  @override
  List<Object?> get props => [kind, contact, number];
}

/// Rede social da entidade (tb_social_media — PK id+kind).
class EntitySocialMedia extends Equatable {
  const EntitySocialMedia({required this.kind, this.link});

  final String  kind;
  final String? link;

  factory EntitySocialMedia.fromJson(Map<String, dynamic> json) =>
      EntitySocialMedia(
        kind: json['kind'] as String? ?? '',
        link: json['link'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'kind': kind,
        if (link != null && link!.isNotEmpty) 'link': link,
      };

  @override
  List<Object?> get props => [kind, link];
}

/// tb_entity + listas de apoio (endereços, fones, redes sociais).
class ObjectEntity extends Equatable {
  const ObjectEntity({
    this.nameCompany = '',
    this.nickTrade = '',
    this.aniversary,
    this.addresses = const [],
    this.phones = const [],
    this.socialMedia = const [],
  });

  /// Razão social (tb_entity.name_company).
  final String nameCompany;

  /// Nome fantasia (tb_entity.nick_trade).
  final String nickTrade;

  /// Aniversário — ISO 'yyyy-MM-dd' (null = não informado).
  final String? aniversary;

  final List<EntityAddress>     addresses;
  final List<EntityPhone>       phones;
  final List<EntitySocialMedia> socialMedia;

  Map<String, dynamic> entityToJson() => {
        'nameCompany': nameCompany,
        'nickTrade':   nickTrade,
        if (aniversary != null) 'aniversary': aniversary,
      };

  /// Parse defensivo das 3 listas do GET :id.
  static List<T> listFromJson<T>(
          dynamic list, T Function(Map<String, dynamic>) fromJson) =>
      (list as List<dynamic>? ?? [])
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList();

  @override
  List<Object?> get props =>
      [nameCompany, nickTrade, aniversary, addresses, phones, socialMedia];
}
