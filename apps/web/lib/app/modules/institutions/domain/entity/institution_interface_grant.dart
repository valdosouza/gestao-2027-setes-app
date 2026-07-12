/// Linha do contrato comercial de interfaces do estabelecimento
/// (tb_institution_has_interface — decisões 17/18/23 da Fase 1):
/// catálogo completo + situação do contrato do cliente alvo.
/// Fonte: GET /api/admin/institutions/:id/interfaces.
class InstitutionInterfaceGrant {
  const InstitutionInterfaceGrant({
    required this.id,
    this.description,
    this.groupDefault,
    this.granted = false,
  });

  factory InstitutionInterfaceGrant.fromJson(Map<String, dynamic> json) =>
      InstitutionInterfaceGrant(
        id:           (json['id'] as num).toInt(),
        description:  json['description'] as String?,
        groupDefault: json['groupDefault'] as String?,
        granted:      json['granted'] == true,
      );

  final int id;
  final String? description;

  /// Agrupador de menu do catálogo — cabeçalhos da lista.
  final String? groupDefault;

  /// true = interface contratada (active='S' no schema do cliente).
  final bool granted;

  InstitutionInterfaceGrant copyWith({bool? granted}) =>
      InstitutionInterfaceGrant(
        id: id,
        description: description,
        groupDefault: groupDefault,
        granted: granted ?? this.granted,
      );
}
