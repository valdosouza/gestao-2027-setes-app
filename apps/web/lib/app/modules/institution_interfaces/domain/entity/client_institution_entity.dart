import 'package:core/core.dart';

/// Estabelecimento cliente na lista da tela "Interfaces dos clientes"
/// (GET /api/institution-interfaces — D-PV11). Para o usuário liberado pelo
/// Super a lista não traz a própria Setes (só o Super mexe nela).
class ClientInstitutionEntity {
  const ClientInstitutionEntity({required this.id, this.name, this.active = true});

  factory ClientInstitutionEntity.fromJson(Map<String, dynamic> json) => ClientInstitutionEntity(
        id: jsonInt(json['id']) ?? 0,
        name: json['name'] as String?,
        active: json['active'] != 'N',
      );

  final int id;
  final String? name;
  final bool active;
}
