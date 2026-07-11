import 'package:equatable/equatable.dart';

/// Entidades de referência geográfica (tabelas na setes_central).
/// Acessadas exclusivamente via setes-api /api/super/* — nunca direto ao banco
/// (decisão 1 do prompt_fase1_fundacao.md).

/// Drivers MySQL podem serializar DECIMAL como string ("12.00") — aceitar
/// num E string evita quebrar a lista inteira por um campo numérico.
double? _asDouble(dynamic v) => switch (v) {
      null => null,
      final num n => n.toDouble(),
      final String s => double.tryParse(s),
      _ => null,
    };

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
    this.countryName,
  });

  /// Código IBGE da UF (ex.: Paraná 41) — informado na inclusão, imutável.
  final int     id;
  final int     tbCountryId;
  final String? abbreviation;
  final String? name;
  final double? aliquota;

  /// Nome do país (JOIN da API) — exibição no campo lookup (campo-lookup-fk.md).
  final String? countryName;

  factory StateEntity.fromJson(Map<String, dynamic> json) => StateEntity(
        id:           (json['id'] as num).toInt(),
        tbCountryId:  (json['tbCountryId'] as num).toInt(),
        abbreviation: json['abbreviation'] as String?,
        name:         json['name'] as String?,
        aliquota:     _asDouble(json['aliquota']),
        countryName:  json['countryName'] as String?,
      );

  @override
  List<Object?> get props =>
      [id, tbCountryId, abbreviation, name, aliquota, countryName];
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
    this.stateName,
  });

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
        aliqIss:    _asDouble(json['aliqIss']) ?? 0,
        population: _asDouble(json['population'])?.toInt() ?? 0,
        density:    _asDouble(json['density']) ?? 0,
        area:       _asDouble(json['area']) ?? 0,
        stateName:  json['stateName'] as String?,
      );

  @override
  List<Object?> get props => [id, tbStateId, ibge, name, aliqIss, population, density, area, stateName];
}
