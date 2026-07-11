import 'package:equatable/equatable.dart';

/// Privilégio (setes_central.tb_privilege) — interface 'privileges' do
/// módulo Super. Acesso exclusivamente via setes-api /api/super/* (decisão 1).
///
/// ATENÇÃO: o módulo interfaces/ tem um PrivilegeEntity PRÓPRIO
/// (leitura-para-checkbox). Este aqui é o de CRUD — cada um vive no seu
/// módulo (regra de promoção da ARQUITETURA_MODULOS.md: só promove para
/// shared quando um segundo módulo precisar do MESMO uso).
class PrivilegeEntity extends Equatable {
  const PrivilegeEntity({required this.id, this.description});

  /// Código gerado pelo backend (MAX+1 — decisão do Valdo 2026-07-11,
  /// precedente do cadastro de Interfaces). 0 = ainda não gerado (inclusão).
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
