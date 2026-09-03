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

  /// 'S' / 'N'.
  final String  active;

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
        active:                 json['active'] as String? ?? 'S',
      );

  @override
  List<Object?> get props => [
        id, cityId, cityName, stateAbbreviation, serviceListId,
        serviceListDescription, localIncidence, aliq, municipalCode, active,
      ];
}

/// Body do POST/PUT — mesmo shape do serviceTaxRuleDto da API (Zod: cityId
/// int positivo; serviceListId N.NN; aliq 0–100; municipalCode máx 20 ou
/// null; active S/N).
class ServiceTaxRuleInput extends Equatable {
  const ServiceTaxRuleInput({
    required this.cityId,
    required this.serviceListId,
    required this.aliq,
    this.municipalCode,
    this.active = 'S',
  });

  final int     cityId;
  final String  serviceListId;
  final double  aliq;
  final String? municipalCode;
  final String  active;

  Map<String, dynamic> toJson() => {
        'cityId':        cityId,
        'serviceListId': serviceListId,
        'aliq':          aliq,
        'municipalCode': municipalCode,
        'active':        active,
      };

  @override
  List<Object?> get props => [cityId, serviceListId, aliq, municipalCode, active];
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
