import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

/// Cidade/Município (setes_central.tb_city) — interface 'cities' do módulo Super.
class CityEntity extends Equatable {
  const CityEntity({
    required this.id,
    required this.tbStateId,
    this.ibge,
    this.name,
    this.aliqIss = 0,
    this.population = 0,
    this.density = 0,
    this.area = 0,
    this.stateName,
  });

  /// Código IBGE do município (ex.: Curitiba 4004) — informado na inclusão,
  /// imutável na edição (decisão do Valdo 2026-07-11).
  final int     id;
  final int     tbStateId;
  final String? ibge;
  final String? name;
  final double  aliqIss;
  final int     population;
  final double  density;
  final double  area;

  /// Nome do estado (JOIN da API) — exibição no campo lookup (campo-lookup-fk.md).
  final String? stateName;

  factory CityEntity.fromJson(Map<String, dynamic> json) => CityEntity(
        id:         (json['id'] as num).toInt(),
        tbStateId:  (json['tbStateId'] as num).toInt(),
        ibge:       json['ibge'] as String?,
        name:       json['name'] as String?,
        // jsonDouble/jsonInt: DECIMAL pode chegar como string (caso 2026-07-11)
        aliqIss:    jsonDouble(json['aliqIss']) ?? 0,
        population: jsonInt(json['population']) ?? 0,
        density:    jsonDouble(json['density']) ?? 0,
        area:       jsonDouble(json['area']) ?? 0,
        stateName:  json['stateName'] as String?,
      );

  @override
  List<Object?> get props =>
      [id, tbStateId, ibge, name, aliqIss, population, density, area, stateName];
}
