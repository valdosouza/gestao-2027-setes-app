import 'package:equatable/equatable.dart';

/// Entidades de referência geográfica (tabelas na setes_central).
/// Acessadas exclusivamente via setes-api /api/super/* — nunca direto ao banco
/// (decisão 1 do prompt_fase1_fundacao.md).

class CountryEntity extends Equatable {
  const CountryEntity({required this.id, this.name});

  final int     id;
  final String? name;

  factory CountryEntity.fromJson(Map<String, dynamic> json) => CountryEntity(
        id:   (json['id'] as num).toInt(),
        name: json['name'] as String?,
      );

  @override
  List<Object?> get props => [id, name];
}

class StateEntity extends Equatable {
  const StateEntity({
    required this.id,
    required this.tbCountryId,
    this.abbreviation,
    this.name,
    this.aliquota,
  });

  final int     id;
  final int     tbCountryId;
  final String? abbreviation;
  final String? name;
  final double? aliquota;

  factory StateEntity.fromJson(Map<String, dynamic> json) => StateEntity(
        id:           (json['id'] as num).toInt(),
        tbCountryId:  (json['tbCountryId'] as num).toInt(),
        abbreviation: json['abbreviation'] as String?,
        name:         json['name'] as String?,
        aliquota:     (json['aliquota'] as num?)?.toDouble(),
      );

  @override
  List<Object?> get props => [id, tbCountryId, abbreviation, name, aliquota];
}

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
  });

  final int     id;
  final int     tbStateId;
  final String? ibge;
  final String? name;
  final double  aliqIss;
  final int     population;
  final double  density;
  final double  area;

  factory CityEntity.fromJson(Map<String, dynamic> json) => CityEntity(
        id:         (json['id'] as num).toInt(),
        tbStateId:  (json['tbStateId'] as num).toInt(),
        ibge:       json['ibge'] as String?,
        name:       json['name'] as String?,
        aliqIss:    (json['aliqIss'] as num?)?.toDouble() ?? 0,
        population: (json['population'] as num?)?.toInt() ?? 0,
        density:    (json['density'] as num?)?.toDouble() ?? 0,
        area:       (json['area'] as num?)?.toDouble() ?? 0,
      );

  @override
  List<Object?> get props => [id, tbStateId, ibge, name, aliqIss, population, density, area];
}
