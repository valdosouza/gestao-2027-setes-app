import 'package:equatable/equatable.dart';

/// Item da Lista de Serviços da LC 116 (setes_central.tb_service_list —
/// referência fiscal do módulo Super).
/// O id é o PRÓPRIO item da lista ('1.01', '7.02'... formato N.NN), digitado
/// pelo usuário na criação — padrão de código externo: 409 se já existir,
/// imutável na edição. [localIncidence] = município de incidência do ISS:
/// 'P' (do PRESTADOR) ou 'E' (da EXECUÇÃO do serviço).
class ServiceListEntity extends Equatable {
  const ServiceListEntity({
    required this.id,
    this.description,
    this.localIncidence = 'P',
    this.active = true,
  });

  final String  id;
  final String? description;
  final String  localIncidence;
  final bool    active;

  factory ServiceListEntity.fromJson(Map<String, dynamic> json) =>
      ServiceListEntity(
        id:             json['id'] as String? ?? '',
        description:    json['description'] as String?,
        localIncidence: json['localIncidence'] as String? ?? 'P',
        active:         (json['active'] as String?) == 'S',
      );

  /// Body do PUT (sem id — imutável); o POST acrescenta o id.
  Map<String, dynamic> toJson() => {
        'description':    description,
        'localIncidence': localIncidence,
        'active':         active ? 'S' : 'N',
      };

  Map<String, dynamic> toCreateJson() => {'id': id, ...toJson()};

  @override
  List<Object?> get props => [id, description, localIncidence, active];
}
