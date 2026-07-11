import 'package:equatable/equatable.dart';

/// Privilégio (setes_central.tb_privilege) — lista de apoio dos checkboxes
/// da tela de Interfaces. Vive DENTRO do módulo interfaces (regra de
/// promoção da ARQUITETURA_MODULOS.md: só promove para shared quando um
/// SEGUNDO módulo precisar).
///
/// O label exibido é a description direto do banco, sem tradução
/// (decisão do Valdo 2026-07-11).
class PrivilegeEntity extends Equatable {
  const PrivilegeEntity({required this.id, this.description});

  final int     id;
  final String? description;

  factory PrivilegeEntity.fromJson(Map<String, dynamic> json) =>
      PrivilegeEntity(
        id:          (json['id'] as num).toInt(),
        description: json['description'] as String?,
      );

  @override
  List<Object?> get props => [id, description];
}
