import 'package:equatable/equatable.dart';

/// Categoria de produtos e serviços (tb_category no schema do cliente) —
/// cadastro RECURSIVO em ÁRVORE (porta do reg_category.pas; decisões do
/// Valdo 2026-07-18): `positLevel` é o caminho materializado ('001',
/// '001.005'...) calculado pela API na criação; `parentId` derivado do
/// caminho (null = nível raiz). Duas árvores por kind: 'P' = produtos,
/// 'S' = serviços (abas da tela; kind imutável). id gerado MAX+1 por
/// institution no backend (0 = ainda não gerado, inclusão).
class CategoryEntity extends Equatable {
  const CategoryEntity({
    required this.id,
    this.description,
    this.positLevel = '',
    this.parentId,
    this.kind = 'P',
    this.active = true,
  });

  final int     id;
  final String? description;

  /// Caminho materializado — SOMENTE LEITURA (a API calcula/move).
  final String  positLevel;

  /// id do nível superior (null = raiz).
  final int?    parentId;

  /// 'P' = produtos, 'S' = serviços (árvore — imutável após criar).
  final String  kind;
  final bool    active;

  /// Profundidade na árvore (0 = raiz).
  int get depth => positLevel.isEmpty ? 0 : '.'.allMatches(positLevel).length;

  factory CategoryEntity.fromJson(Map<String, dynamic> json) => CategoryEntity(
        id:          (json['id'] as num).toInt(),
        description: json['description'] as String?,
        positLevel:  json['positLevel'] as String? ?? '',
        parentId:    (json['parentId'] as num?)?.toInt(),
        kind:        json['kind'] as String? ?? 'P',
        active:      (json['active'] as String?) == 'S',
      );

  /// Body do POST (kind define a árvore; parentId null = raiz).
  Map<String, dynamic> toCreateJson() => {
        'description': description,
        'kind':        kind,
        'parentId':    parentId,
        'active':      active ? 'S' : 'N',
      };

  /// Body do PUT (kind não muda; parentId diferente do atual = MOVER —
  /// a API recalcula o posit_level da subárvore).
  Map<String, dynamic> toUpdateJson() => {
        'description': description,
        'parentId':    parentId,
        'active':      active ? 'S' : 'N',
      };

  @override
  List<Object?> get props =>
      [id, description, positLevel, parentId, kind, active];
}
