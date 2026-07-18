import 'package:equatable/equatable.dart';

/// CFOP (setes_central.tb_cfop — referência fiscal do módulo Super).
/// O id é o PRÓPRIO código CFOP (string, digitado pelo usuário na criação —
/// padrão de código externo: 409 se já existir, imutável na edição).
/// Semântica do legado (reg_cfop.pas): way = Sentido E/S; jurisdiction =
/// Alçada E(stadual)/N(acional)/X(Exterior); register = "Registro" (inteiro
/// livre); note = "Aplicação" (texto longo).
class CfopEntity extends Equatable {
  const CfopEntity({
    required this.id,
    this.description,
    this.concise,
    this.register,
    this.way,
    this.jurisdiction,
    this.note,
    this.active = true,
  });

  final String  id;
  final String? description;
  final String? concise;
  final int?    register;
  final String? way;
  final String? jurisdiction;
  final String? note;
  final bool    active;

  factory CfopEntity.fromJson(Map<String, dynamic> json) => CfopEntity(
        id:           json['id'] as String? ?? '',
        description:  json['description'] as String?,
        concise:      json['concise'] as String?,
        register:     (json['register'] as num?)?.toInt(),
        way:          json['way'] as String?,
        jurisdiction: json['jurisdiction'] as String?,
        note:         json['note'] as String?,
        active:       (json['active'] as String?) == 'S',
      );

  static String? _trimOrNull(String? value) {
    final t = value?.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  /// Body do PUT (sem id — imutável); o POST acrescenta o id.
  Map<String, dynamic> toJson() => {
        'description':  description,
        'concise':      _trimOrNull(concise),
        'register':     register,
        'way':          way,
        'jurisdiction': jurisdiction,
        'note':         _trimOrNull(note),
        'active':       active ? 'S' : 'N',
      };

  Map<String, dynamic> toCreateJson() => {'id': id, ...toJson()};

  @override
  List<Object?> get props =>
      [id, description, concise, register, way, jurisdiction, note, active];
}
