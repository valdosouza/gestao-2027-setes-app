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
    this.serviceTaxRuleId,
    this.serviceTaxRuleLabel,
    this.promotion = 'N',
    this.highlights = 'N',
    this.published = 'N',
    this.note,
    this.prices = const [],
    this.nbs,
    this.nbsDescription,
    this.ibscbs,
  });

  final int?    financialPlansId;
  final String? financialPlansDescription;

  /// Regra de Tributação de Serviço apontada (D1 — FK literal) + rótulo
  /// de exibição montado pela API ("1.02 · Curitiba/PR · 5.00%").
  final int?    serviceTaxRuleId;
  final String? serviceTaxRuleLabel;
  final String  promotion;
  final String  highlights;
  final String  published;
  final String? note;

  /// Grade: TODAS as tabelas de preço vivas com o preço atual (null = sem).
  final List<ServicePrice> prices;

  /// Fase IBS/CBS (D-IB6): NBS do serviço — 9 dígitos SEM pontos (null =
  /// sem NBS) + descrição oficial (JOIN da API com o catálogo central).
  final String? nbs;
  final String? nbsDescription;

  /// Classificação IBS/CBS que o serviço presume (peça 1:1
  /// tb_service_ibscbs); null = não classificado.
  final ServiceIbscbs? ibscbs;

  /// Exibição da NBS no MESMO formato da lista de apoio
  /// ("115022000 — descrição"); '' sem NBS.
  String get nbsDisplay => _codeDisplay(nbs, nbsDescription);

  factory ServiceFull.fromJson(Map<String, dynamic> json) => ServiceFull(
        id:                        jsonInt(json['id']) ?? 0,
        identifier:                json['identifier'] as String? ?? '',
        description:               json['description'] as String? ?? '',
        categoryId:                jsonInt(json['categoryId']) ?? 0,
        categoryDescription:       json['categoryDescription'] as String?,
        active:                    json['active'] as String? ?? 'S',
        financialPlansId:          jsonInt(json['financialPlansId']),
        financialPlansDescription: json['financialPlansDescription'] as String?,
        serviceTaxRuleId:          jsonInt(json['serviceTaxRuleId']),
        serviceTaxRuleLabel:       json['serviceTaxRuleLabel'] as String?,
        promotion:                 json['promotion'] as String? ?? 'N',
        highlights:                json['highlights'] as String? ?? 'N',
        published:                 json['published'] as String? ?? 'N',
        note:                      json['note'] as String?,
        prices: (json['prices'] as List<dynamic>? ?? const [])
            .map((e) => ServicePrice.fromJson(e as Map<String, dynamic>))
            .toList(),
        nbs:            _jsonCode(json['nbs']),
        nbsDescription: json['nbsDescription'] as String?,
        ibscbs: json['ibscbs'] is Map<String, dynamic>
            ? ServiceIbscbs.fromJson(json['ibscbs'] as Map<String, dynamic>)
            : null,
      );

  @override
  List<Object?> get props => [
        ...super.props, financialPlansId, financialPlansDescription,
        serviceTaxRuleId, serviceTaxRuleLabel,
        promotion, highlights, published, note, prices,
        nbs, nbsDescription, ibscbs,
      ];
}

/// Código oficial vindo da API → texto aparado (null quando vazio).
/// Tolera número (JSON mal tipado), mas código com zero à esquerda só
/// sobrevive como string — que é o contrato da API.
String? _jsonCode(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

/// "código — descrição": o mesmo formato que a API devolve nas listas de
/// apoio (CONCAT(code, ' — ', description)); '' sem código.
String _codeDisplay(String? code, String? description) {
  if (code == null || code.isEmpty) return '';
  final text = description?.trim() ?? '';
  return text.isEmpty ? code : '$code — $text';
}

/// CST do IBS/CBS = os 3 primeiros dígitos do cClassTrib (espelho do
/// `deriveCst` da API — o CST NUNCA é escolhido nem gravado, só exibido).
String deriveIbscbsCst(String classificationCode) =>
    classificationCode.length >= 3
        ? classificationCode.substring(0, 3)
        : classificationCode;

/// Classificação IBS/CBS do serviço (GET /api/services/:id → `ibscbs`):
/// cClassTrib + cIndOp ESCOLHIDOS (D-IB6); [cst] derivado pela API;
/// nome/descrição do catálogo central só para exibir.
class ServiceIbscbs extends Equatable {
  const ServiceIbscbs({
    required this.classificationCode,
    required this.cst,
    this.classificationName,
    this.validFrom,
    this.validUntil,
    this.acceptedToday,
    this.classificationAcceptedToday,
    this.placeIndicatorAcceptedToday,
    required this.placeIndicatorCode,
    this.placeIndicatorDescription,
  });

  /// cClassTrib — 6 dígitos.
  final String  classificationCode;

  /// CST derivado (3 dígitos) — SÓ exibição.
  final String  cst;
  final String? classificationName;

  /// Vigência da linha exibida (AAAA-MM-DD — D-IB29: a tela mostra
  /// "vale a partir de" / "válida até").
  final String? validFrom;
  final String? validUntil;

  /// D-IB37: a classificação GRAVADA é aceita hoje na NFS-e? (null = não
  /// avaliado) — false mostra o selo na aba.
  final bool? acceptedToday;

  /// Por COMPONENTE (o selo aponta o campo certo): cClassTrib e cIndOp.
  final bool? classificationAcceptedToday;
  final bool? placeIndicatorAcceptedToday;

  /// cIndOp (indicador da operação — Anexo VII) — 6 dígitos.
  final String  placeIndicatorCode;
  final String? placeIndicatorDescription;

  /// "CST · cClassTrib — nome": o MESMO formato da lista de apoio.
  String get classificationDisplay {
    final name = classificationName?.trim() ?? '';
    final head = '$cst · $classificationCode';
    return name.isEmpty ? head : '$head — $name';
  }

  /// "cIndOp — descrição": o MESMO formato da lista de apoio.
  String get placeIndicatorDisplay =>
      _codeDisplay(placeIndicatorCode, placeIndicatorDescription);

  factory ServiceIbscbs.fromJson(Map<String, dynamic> json) {
    final classification = _jsonCode(json['classificationCode']) ?? '';
    return ServiceIbscbs(
      classificationCode:        classification,
      cst: _jsonCode(json['cst']) ?? deriveIbscbsCst(classification),
      classificationName:        json['classificationName'] as String?,
      validFrom:                 json['validFrom'] as String?,
      validUntil:                json['validUntil'] as String?,
      acceptedToday:             json['acceptedToday'] as bool?,
      classificationAcceptedToday: json['classificationAcceptedToday'] as bool?,
      placeIndicatorAcceptedToday: json['placeIndicatorAcceptedToday'] as bool?,
      placeIndicatorCode:        _jsonCode(json['placeIndicatorCode']) ?? '',
      placeIndicatorDescription: json['placeIndicatorDescription'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        classificationCode, cst, classificationName, validFrom, validUntil,
        acceptedToday, classificationAcceptedToday, placeIndicatorAcceptedToday,
        placeIndicatorCode, placeIndicatorDescription,
      ];
}

/// Classificação IBS/CBS no PAYLOAD: os DOIS códigos vão JUNTOS (a tela
/// barra o par incompleto antes de salvar — service_ibscbs_rules.dart).
class ServiceIbscbsInput extends Equatable {
  const ServiceIbscbsInput({
    required this.classificationCode,
    required this.placeIndicatorCode,
  });

  final String classificationCode;
  final String placeIndicatorCode;

  Map<String, dynamic> toJson() => {
        'classificationCode': classificationCode,
        'placeIndicatorCode': placeIndicatorCode,
      };

  @override
  List<Object?> get props => [classificationCode, placeIndicatorCode];
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
/// categoryId obrigatório; financialPlansId e serviceTaxRuleId opcionais
/// (null = sem vínculo); flags S/N; note máx 4000; prices[] sem tabela
/// duplicada). Fase IBS/CBS: `nbs` (9 dígitos) e `ibscbs` (par cClassTrib +
/// cIndOp) — na API "ausente = não mexe · null = remove"; esta tela SEMPRE
/// manda os dois com o estado dela (null quando vazios).
class ServiceInput extends Equatable {
  const ServiceInput({
    this.identifier,
    required this.description,
    required this.categoryId,
    this.financialPlansId,
    this.serviceTaxRuleId,
    this.promotion = 'N',
    this.highlights = 'N',
    this.published = 'N',
    this.active = 'S',
    this.note,
    this.prices = const [],
    this.nbs,
    this.ibscbs,
  });

  final String? identifier;
  final String  description;
  final int     categoryId;
  final int?    financialPlansId;
  final int?    serviceTaxRuleId;
  final String  promotion;
  final String  highlights;
  final String  published;
  final String  active;
  final String? note;
  final List<ServicePriceInput> prices;

  /// NBS sem pontos; null = sem NBS (a API remove).
  final String? nbs;

  /// Classificação IBS/CBS; null = não classificado (a API remove).
  final ServiceIbscbsInput? ibscbs;

  Map<String, dynamic> toJson() => {
        'identifier':       identifier,
        'description':      description,
        'categoryId':       categoryId,
        'financialPlansId': financialPlansId,
        'serviceTaxRuleId': serviceTaxRuleId,
        'promotion':        promotion,
        'highlights':       highlights,
        'published':        published,
        'active':           active,
        'note':             note,
        'prices':           prices.map((p) => p.toJson()).toList(),
        // SEMPRE presentes (null = remove) — a tela é a dona do estado.
        'nbs':              nbs,
        'ibscbs':           ibscbs?.toJson(),
      };

  @override
  List<Object?> get props => [
        identifier, description, categoryId, financialPlansId,
        serviceTaxRuleId, promotion, highlights, published, active, note,
        prices, nbs, ibscbs,
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

/// Item das listas de apoio da fase IBS/CBS (GET /api/services/nbs,
/// /ibscbs-classifications e /ibscbs-place-indicators → {code, description}).
/// [code] é o CÓDIGO OFICIAL em texto (zero à esquerda importa — '000001'),
/// não um id numérico; [description] já vem formatada pela API para exibir
/// ("código — descrição"; na classificação "CST · código — nome").
class ServiceCodeLookup extends Equatable {
  const ServiceCodeLookup({
    required this.code,
    this.description,
    this.validFrom,
    this.validUntil,
  });

  final String  code;
  final String? description;

  /// Só nas classificações (D-IB29): vigência da linha oferecida.
  final String? validFrom;
  final String? validUntil;

  String get display => description ?? code;

  factory ServiceCodeLookup.fromJson(Map<String, dynamic> json) =>
      ServiceCodeLookup(
        code:        _jsonCode(json['code']) ?? '',
        description: json['description'] as String?,
        validFrom:   json['validFrom'] as String?,
        validUntil:  json['validUntil'] as String?,
      );

  @override
  List<Object?> get props => [code, description, validFrom, validUntil];
}
