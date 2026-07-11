import 'package:equatable/equatable.dart';

/// Item de lookup de País — versão MÍNIMA para listas de apoio (FK).
///
/// Vive em app/shared/lookup porque é usado por 2+ módulos (regra de
/// promoção da ARQUITETURA_MODULOS.md): o módulo states escolhe o país
/// do estado por aqui. O CRUD completo de País pertence ao módulo
/// countries (CountryEntity) — módulo nunca importa módulo.
class CountryLookup extends Equatable {
  const CountryLookup({required this.id, this.name});

  final int     id;
  final String? name;

  factory CountryLookup.fromJson(Map<String, dynamic> json) => CountryLookup(
        id:   (json['id'] as num).toInt(),
        name: json['name'] as String?,
      );

  @override
  List<Object?> get props => [id, name];
}
