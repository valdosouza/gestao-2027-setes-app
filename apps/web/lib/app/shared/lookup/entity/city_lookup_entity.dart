import 'package:equatable/equatable.dart';

/// Item de lookup de Cidade — versão MÍNIMA para listas de apoio (FK).
///
/// Vive em app/shared/lookup porque é usado por 2+ módulos (regra de
/// promoção da ARQUITETURA_MODULOS.md): a aba de Endereços da cadeia de
/// entidade fiscal (Institution/Customer/Provider/...) escolhe a cidade
/// por aqui. O CRUD completo de Cidade pertence ao módulo cities
/// (CityEntity) — módulo nunca importa módulo.
class CityLookup extends Equatable {
  const CityLookup({required this.id, this.name, this.tbStateId});

  final int     id;
  final String? name;
  final int?    tbStateId;

  factory CityLookup.fromJson(Map<String, dynamic> json) => CityLookup(
        id:        (json['id'] as num).toInt(),
        name:      json['name'] as String?,
        tbStateId: (json['tbStateId'] as num?)?.toInt(),
      );

  @override
  List<Object?> get props => [id, name, tbStateId];
}
