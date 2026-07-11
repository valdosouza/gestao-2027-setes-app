import 'package:equatable/equatable.dart';

/// Interface do sistema (setes_central.tb_interface) — interface 'interfaces'
/// do módulo Super. Acesso exclusivamente via setes-api /api/super/* (decisão 1).
///
/// O id é gerado pelo backend (MAX+1 — sem padrão externo tipo BACEN/IBGE,
/// decisão do Valdo 2026-07-11): aparece readOnly no formulário, vazio na
/// inclusão e preenchido na edição.
class InterfaceEntity extends Equatable {
  const InterfaceEntity({
    required this.id,
    this.groupDefault,
    this.i18nKey,
    this.description,
    this.kind,
    this.position,
    this.privilegeIds = const [],
  });

  final int     id;
  final String? groupDefault;
  final String? i18nKey;
  final String? description;
  final String? kind;
  final String? position;

  /// Privilégios vinculados (tb_interface_has_privilege ativos) —
  /// selecionados via checkboxes na tela (decisão do Valdo 2026-07-11).
  final List<int> privilegeIds;

  factory InterfaceEntity.fromJson(Map<String, dynamic> json) =>
      InterfaceEntity(
        id:           (json['id'] as num).toInt(),
        groupDefault: json['groupDefault'] as String?,
        i18nKey:      json['i18nKey'] as String?,
        description:  json['description'] as String?,
        kind:         json['kind'] as String?,
        position:     json['position'] as String?,
        privilegeIds: (json['privilegeIds'] as List<dynamic>? ?? [])
            .map((e) => (e as num).toInt())
            .toList(),
      );

  @override
  List<Object?> get props =>
      [id, groupDefault, i18nKey, description, kind, position, privilegeIds];
}
