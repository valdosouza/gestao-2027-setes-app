import 'package:equatable/equatable.dart';

/// País (setes_central.tb_country) — interface 'countries' do módulo Super.
/// Acesso exclusivamente via setes-api /api/super/* (decisão 1).
class CountryEntity extends Equatable {
  const CountryEntity({required this.id, this.name});

  /// Código mundial do país (padrão BACEN — ex.: Brasil 1058), informado
  /// pelo usuário na inclusão e imutável na edição (decisão 2026-07-10).
  final int     id;
  final String? name;

  factory CountryEntity.fromJson(Map<String, dynamic> json) => CountryEntity(
        id:   (json['id'] as num).toInt(),
        name: json['name'] as String?,
      );

  @override
  List<Object?> get props => [id, name];
}
