import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

/// Entidades do módulo service_tax_rules — Regra de Tributação de SERVIÇO
/// (ISS), prompt_regra_tributacao_servico.md (D1–D14, 2026-09-02): o que o
/// MUNICÍPIO cobra de um item da Lista de Serviços (LC 116) — cidade de
/// INCIDÊNCIA (D12) × item → alíquota (D13) + código municipal (D4).
/// Espelho do /api/service-tax-rules (tb_service_tax_rule no schema do
/// cliente; id MAX+1 da API). A lista e o GET /:id devolvem o MESMO shape.

/// Linha da pesquisa E objeto completo (GET /api/service-tax-rules[/:id]) —
/// cidade/UF e descrição do item vêm por JOIN da API (só exibição).
class ServiceTaxRuleEntity extends Equatable {
  const ServiceTaxRuleEntity({
    required this.id,
    required this.cityId,
    this.cityName,
    this.stateAbbreviation,
    required this.serviceListId,
    this.serviceListDescription,
    this.localIncidence,
    required this.aliq,
    this.municipalCode,
    this.nationalCode,
    this.effectiveNationalCode,
    this.nationalCodeOptions = 0,
    this.active = 'S',
  });

  final int     id;
  final int     cityId;
  final String? cityName;
  final String? stateAbbreviation;

  /// Item da LC 116 ('1.02').
  final String  serviceListId;
  final String? serviceListDescription;

  /// 'P' prestador / 'E' execução — informativo (vem do catálogo central).
  final String? localIncidence;

  /// Alíquota do ISS em % (0–100).
  final double  aliq;
  final String? municipalCode;

  /// Código de tributação NACIONAL (cTribNac, 6 dígitos — Onda 3 NFS-e)
  /// GRAVADO na regra; null quando o item tem um único desdobro e o código
  /// é derivado.
  final String? nationalCode;

  /// Código efetivo: o gravado ou o derivado do item (null = item sem
  /// código nacional no catálogo).
  final String? effectiveNationalCode;

  /// Quantos desdobros o subitem tem no catálogo nacional — >1 exige a
  /// escolha explícita do usuário.
  final int     nationalCodeOptions;

  /// 'S' / 'N'.
  final String  active;

  /// O código efetivo é DERIVADO (nada gravado, o item só tem um desdobro).
  bool get nationalCodeDerived =>
      nationalCode == null && effectiveNationalCode != null;

  /// Exibição do item: "1.02 - Programação".
  String get serviceListDisplay {
    final d = serviceListDescription ?? '';
    return d.isEmpty ? serviceListId : '$serviceListId - $d';
  }

  /// Exibição da cidade: "Curitiba/PR".
  String get cityDisplay {
    final c = cityName ?? '';
    final uf = stateAbbreviation ?? '';
    return uf.isEmpty ? c : '$c/$uf';
  }

  factory ServiceTaxRuleEntity.fromJson(Map<String, dynamic> json) =>
      ServiceTaxRuleEntity(
        id:                     jsonInt(json['id']) ?? 0,
        cityId:                 jsonInt(json['cityId']) ?? 0,
        cityName:               json['cityName'] as String?,
        stateAbbreviation:      json['stateAbbreviation'] as String?,
        serviceListId:          '${json['serviceListId'] ?? ''}',
        serviceListDescription: json['serviceListDescription'] as String?,
        localIncidence:         json['localIncidence'] as String?,
        // mysql2 devolve DECIMAL como string — jsonDouble é tolerante.
        aliq:                   jsonDouble(json['aliq']) ?? 0,
        municipalCode:          json['municipalCode'] as String?,
        nationalCode:           _codeOrNull(json['nationalCode']),
        effectiveNationalCode:  _codeOrNull(json['effectiveNationalCode']),
        nationalCodeOptions:    jsonInt(json['nationalCodeOptions']) ?? 0,
        active:                 json['active'] as String? ?? 'S',
      );

  /// Código de 6 dígitos pode chegar como string ou número — normaliza;
  /// vazio vira null.
  static String? _codeOrNull(dynamic v) {
    if (v == null) return null;
    final s = '$v'.trim();
    return s.isEmpty ? null : s;
  }

  @override
  List<Object?> get props => [
        id, cityId, cityName, stateAbbreviation, serviceListId,
        serviceListDescription, localIncidence, aliq, municipalCode,
        nationalCode, effectiveNationalCode, nationalCodeOptions, active,
      ];
}

/// Body do POST/PUT — mesmo shape do serviceTaxRuleDto da API (Zod: cityId
/// int positivo; serviceListId N.NN; aliq 0–100; municipalCode máx 20 ou
/// null; nationalCode 6 dígitos opcional — null quando derivado; active S/N).
class ServiceTaxRuleInput extends Equatable {
  const ServiceTaxRuleInput({
    required this.cityId,
    required this.serviceListId,
    required this.aliq,
    this.municipalCode,
    this.nationalCode,
    this.active = 'S',
  });

  final int     cityId;
  final String  serviceListId;
  final double  aliq;
  final String? municipalCode;

  /// Código de tributação nacional ESCOLHIDO (item com vários desdobros);
  /// null = derivado pela API (item com um só).
  final String? nationalCode;
  final String  active;

  Map<String, dynamic> toJson() => {
        'cityId':        cityId,
        'serviceListId': serviceListId,
        'aliq':          aliq,
        'municipalCode': municipalCode,
        'nationalCode':  nationalCode,
        'active':        active,
      };

  @override
  List<Object?> get props =>
      [cityId, serviceListId, aliq, municipalCode, nationalCode, active];
}

/// Desdobro do subitem na tributação nacional (cTribNac) para o lookup
/// dependente do item (GET /api/service-tax-rules/national-codes
/// ?serviceListId=1.02 → {id:'010201', description}).
class NationalCodeLookup extends Equatable {
  const NationalCodeLookup({required this.id, this.description});

  /// Código de 6 dígitos ('010201').
  final String  id;
  final String? description;

  /// Exibição: "010201 - Descrição".
  String get display {
    final d = description ?? '';
    return d.isEmpty ? id : '$id - $d';
  }

  /// Número do desdobro (2 últimos dígitos: '010201' → 1) — avatar da lista
  /// de apoio (showSetesLookup exige id inteiro).
  int get sequence =>
      int.tryParse(id.length >= 2 ? id.substring(id.length - 2) : id) ?? 0;

  factory NationalCodeLookup.fromJson(Map<String, dynamic> json) =>
      NationalCodeLookup(
        id:          '${json['id'] ?? ''}',
        description: json['description'] as String?,
      );

  @override
  List<Object?> get props => [id, description];
}

/// Item ATIVO da Lista de Serviços para o lookup do form
/// (GET /api/service-tax-rules/service-list → {id:'1.02', description}).
class ServiceListLookup extends Equatable {
  const ServiceListLookup({required this.id, this.description});

  /// Item da LC 116 ('1.02') — id textual do catálogo central.
  final String  id;
  final String? description;

  /// Exibição: "1.02 - Programação".
  String get display {
    final d = description ?? '';
    return d.isEmpty ? id : '$id - $d';
  }

  /// Grupo numérico do item ('1.02' → 1) — avatar da lista de apoio
  /// (showSetesLookup exige id inteiro).
  int get group => int.tryParse(id.split('.').first) ?? 0;

  factory ServiceListLookup.fromJson(Map<String, dynamic> json) =>
      ServiceListLookup(
        id:          '${json['id'] ?? ''}',
        description: json['description'] as String?,
      );

  @override
  List<Object?> get props => [id, description];
}
