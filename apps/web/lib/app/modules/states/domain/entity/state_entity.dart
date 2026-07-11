import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

/// Estado/UF (setes_central.tb_state) — interface 'states' do módulo Super.
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
        // jsonDouble: DECIMAL pode chegar como string (caso 2026-07-11)
        aliquota:     jsonDouble(json['aliquota']),
        countryName:  json['countryName'] as String?,
      );

  @override
  List<Object?> get props =>
      [id, tbCountryId, abbreviation, name, aliquota, countryName];
}
