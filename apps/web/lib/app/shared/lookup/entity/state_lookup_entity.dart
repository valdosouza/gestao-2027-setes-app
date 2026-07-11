import 'package:equatable/equatable.dart';

/// Item de lookup de Estado — versão MÍNIMA para listas de apoio (FK).
///
/// Vive em app/shared/lookup porque é usado por 2+ módulos (regra de
/// promoção da ARQUITETURA_MODULOS.md): o módulo cities escolhe o estado
/// da cidade por aqui. O CRUD completo de Estado pertence ao módulo
/// states (StateEntity) — módulo nunca importa módulo.
class StateLookup extends Equatable {
  const StateLookup({required this.id, this.name, this.abbreviation});

  final int     id;
  final String? name;
  final String? abbreviation;

  factory StateLookup.fromJson(Map<String, dynamic> json) => StateLookup(
        id:           (json['id'] as num).toInt(),
        name:         json['name'] as String?,
        abbreviation: json['abbreviation'] as String?,
      );

  @override
  List<Object?> get props => [id, name, abbreviation];
}
