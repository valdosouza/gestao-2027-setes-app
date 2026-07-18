import 'package:equatable/equatable.dart';

/// Conta do Plano de Contas (tb_financial_plans no schema do cliente) —
/// 2º cadastro RECURSIVO em ÁRVORE (porta do reg_plano_contas.pas; molde
/// categories): `positLevel` materializado calculado pela API; `parentId`
/// derivado do caminho (null = raiz). Árvore ÚNICA — os domínios são
/// atributos da conta (radios, semântica do ControllerPlanoContas.pas):
///   source  = Natureza: 'C' Credora / 'D' Devedora
///   kind    = Tipo: 'C' Centro de Custo / 'R' Contas de Resultado
///   cluster = Nível: 'S' Sintética / 'A' Analítica
class FinancialPlanEntity extends Equatable {
  const FinancialPlanEntity({
    required this.id,
    this.description,
    this.positLevel = '',
    this.parentId,
    this.source = 'C',
    this.kind = 'C',
    this.cluster = 'S',
    this.active = true,
  });

  final int     id;
  final String? description;

  /// Caminho materializado — SOMENTE LEITURA (a API calcula/move).
  final String  positLevel;

  /// id do nível superior (null = raiz).
  final int?    parentId;

  final String  source;
  final String  kind;
  final String  cluster;
  final bool    active;

  factory FinancialPlanEntity.fromJson(Map<String, dynamic> json) =>
      FinancialPlanEntity(
        id:          (json['id'] as num).toInt(),
        description: json['description'] as String?,
        positLevel:  json['positLevel'] as String? ?? '',
        parentId:    (json['parentId'] as num?)?.toInt(),
        source:      json['source'] as String? ?? 'C',
        kind:        json['kind'] as String? ?? 'C',
        cluster:     json['cluster'] as String? ?? 'S',
        active:      (json['active'] as String?) == 'S',
      );

  /// Body do POST/PUT (mesmo shape — financial-plans.dto.ts). No PUT,
  /// parentId diferente do atual = MOVER (a API recalcula a subárvore).
  Map<String, dynamic> toJson() => {
        'description': description,
        'source':      source,
        'kind':        kind,
        'cluster':     cluster,
        'parentId':    parentId,
        'active':      active ? 'S' : 'N',
      };

  @override
  List<Object?> get props =>
      [id, description, positLevel, parentId, source, kind, cluster, active];
}
