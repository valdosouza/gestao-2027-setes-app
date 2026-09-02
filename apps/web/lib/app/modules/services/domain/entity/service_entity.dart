import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

/// Entidades do módulo services — Cadastro de Serviços
/// (prompt_modulo_services.md, rodadas 1–2 FECHADAS 2026-09-01). Serviço =
/// tb_product com kind='S' (natureza por AUSÊNCIA de especialização); D5:
/// caminho INDIVIDUAL — este módulo só enxerga serviço, o /api/services fixa
/// o kind. D4/D7: serviço TEM preço — grade tb_price por tabela de preço
/// viva, salva na MESMA transação do serviço.

/// Linha da PESQUISA (GET /api/services) — categoria via JOIN da API.
class ServiceListItem extends Equatable {
  const ServiceListItem({
    required this.id,
    this.identifier = '',
    required this.description,
    required this.categoryId,
    this.categoryDescription,
    this.active = 'S',
  });

  final int     id;
  final String  identifier;
  final String  description;
  final int     categoryId;
  final String? categoryDescription;

  /// 'S' / 'N'.
  final String  active;

  factory ServiceListItem.fromJson(Map<String, dynamic> json) =>
      ServiceListItem(
        id:                  jsonInt(json['id']) ?? 0,
        identifier:          json['identifier'] as String? ?? '',
        description:         json['description'] as String? ?? '',
        categoryId:          jsonInt(json['categoryId']) ?? 0,
        categoryDescription: json['categoryDescription'] as String?,
        active:              json['active'] as String? ?? 'S',
      );

  @override
  List<Object?> get props =>
      [id, identifier, description, categoryId, categoryDescription, active];
}

/// Linha da GRADE de preços (aba Preços): uma por tabela de preço viva;
/// [priceTag] null = serviço sem preço nessa tabela.
class ServicePrice extends Equatable {
  const ServicePrice({
    required this.priceListId,
    this.priceListDescription,
    this.priceTag,
  });

  final int     priceListId;
  final String? priceListDescription;
  final double? priceTag;

  factory ServicePrice.fromJson(Map<String, dynamic> json) => ServicePrice(
        priceListId:          jsonInt(json['priceListId']) ?? 0,
        priceListDescription: json['priceListDescription'] as String?,
        priceTag:             jsonDouble(json['priceTag']),
      );

  /// Grade do serviço NOVO: monta a linha a partir da tabela de preço
  /// (GET /api/price-lists) ainda sem preço.
  factory ServicePrice.fromPriceListJson(Map<String, dynamic> json) =>
      ServicePrice(
        priceListId:          jsonInt(json['id']) ?? 0,
        priceListDescription: json['description'] as String?,
      );

  @override
  List<Object?> get props => [priceListId, priceListDescription, priceTag];
}

/// Serviço COMPLETO (GET /api/services/:id) — a lista não traz plano
/// financeiro, flags, observação nem a grade de preços.
class ServiceFull extends ServiceListItem {
  const ServiceFull({
    required super.id,
    super.identifier,
    required super.description,
    required super.categoryId,
    super.categoryDescription,
    super.active,
    this.financialPlansId,
    this.financialPlansDescription,
    this.promotion = 'N',
    this.highlights = 'N',
    this.published = 'N',
    this.note,
    this.prices = const [],
  });

  final int?    financialPlansId;
  final String? financialPlansDescription;
  final String  promotion;
  final String  highlights;
  final String  published;
  final String? note;

  /// Grade: TODAS as tabelas de preço vivas com o preço atual (null = sem).
  final List<ServicePrice> prices;

  factory ServiceFull.fromJson(Map<String, dynamic> json) => ServiceFull(
        id:                        jsonInt(json['id']) ?? 0,
        identifier:                json['identifier'] as String? ?? '',
        description:               json['description'] as String? ?? '',
        categoryId:                jsonInt(json['categoryId']) ?? 0,
        categoryDescription:       json['categoryDescription'] as String?,
        active:                    json['active'] as String? ?? 'S',
        financialPlansId:          jsonInt(json['financialPlansId']),
        financialPlansDescription: json['financialPlansDescription'] as String?,
        promotion:                 json['promotion'] as String? ?? 'N',
        highlights:                json['highlights'] as String? ?? 'N',
        published:                 json['published'] as String? ?? 'N',
        note:                      json['note'] as String?,
        prices: (json['prices'] as List<dynamic>? ?? const [])
            .map((e) => ServicePrice.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  List<Object?> get props => [
        ...super.props, financialPlansId, financialPlansDescription,
        promotion, highlights, published, note, prices,
      ];
}

/// Linha da grade no PAYLOAD: [priceTag] null = remover o preço da tabela
/// (a API faz o soft delete); a tela envia TODAS as linhas da grade.
class ServicePriceInput extends Equatable {
  const ServicePriceInput({required this.priceListId, this.priceTag});

  final int     priceListId;
  final double? priceTag;

  Map<String, dynamic> toJson() => {
        'priceListId': priceListId,
        'priceTag':    priceTag,
      };

  @override
  List<Object?> get props => [priceListId, priceTag];
}

/// Body do POST/PUT — mesmo shape do serviceDto da API (Zod: identifier
/// máx 50 opcional — em branco a API usa o id (D1); description 1..100;
/// categoryId obrigatório; financialPlansId opcional; flags S/N; note
/// máx 4000; prices[] sem tabela duplicada).
class ServiceInput extends Equatable {
  const ServiceInput({
    this.identifier,
    required this.description,
    required this.categoryId,
    this.financialPlansId,
    this.promotion = 'N',
    this.highlights = 'N',
    this.published = 'N',
    this.active = 'S',
    this.note,
    this.prices = const [],
  });

  final String? identifier;
  final String  description;
  final int     categoryId;
  final int?    financialPlansId;
  final String  promotion;
  final String  highlights;
  final String  published;
  final String  active;
  final String? note;
  final List<ServicePriceInput> prices;

  Map<String, dynamic> toJson() => {
        'identifier':       identifier,
        'description':      description,
        'categoryId':       categoryId,
        'financialPlansId': financialPlansId,
        'promotion':        promotion,
        'highlights':       highlights,
        'published':        published,
        'active':           active,
        'note':             note,
        'prices':           prices.map((p) => p.toJson()).toList(),
      };

  @override
  List<Object?> get props => [
        identifier, description, categoryId, financialPlansId,
        promotion, highlights, published, active, note, prices,
      ];
}

/// Item dos lookups de apoio do form (GET /api/services/categories e
/// /api/services/financial-plans → {id, description}).
class ServiceLookup extends Equatable {
  const ServiceLookup({required this.id, this.description});

  final int     id;
  final String? description;

  String get display => description ?? '';

  factory ServiceLookup.fromJson(Map<String, dynamic> json) => ServiceLookup(
        id:          jsonInt(json['id']) ?? 0,
        description: json['description'] as String?,
      );

  @override
  List<Object?> get props => [id, description];
}
