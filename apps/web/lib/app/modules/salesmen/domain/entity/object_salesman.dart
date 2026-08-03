import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

/// Linha da PESQUISA de Vendedores (GET /api/salesmen).
class SalesmanListItem extends Equatable {
  const SalesmanListItem({
    required this.id,
    this.nickTrade,
    this.nameCompany,
    this.active = false,
  });

  final int     id;
  final String? nickTrade;
  final String? nameCompany;
  final bool    active;

  factory SalesmanListItem.fromJson(Map<String, dynamic> json) =>
      SalesmanListItem(
        id:          (json['id'] as num).toInt(),
        nickTrade:   json['nickTrade'] as String?,
        nameCompany: json['nameCompany'] as String?,
        active:      (json['active'] as String?) == 'S',
      );

  @override
  List<Object?> get props => [id, nickTrade, nameCompany, active];
}

/// Papel Vendedor — Onda 2 da Entidade Única (D1): vendedor é PROMOÇÃO de
/// um colaborador, então este cadastro NÃO usa a cadeia fiscal — a
/// identificação ([nickTrade]/[nameCompany]/[document]) vem READONLY do
/// colaborador promovido (GET :id) ou do lookup de colaboradores (criação);
/// editáveis são só os campos do papel (tb_salesman).
class ObjectSalesman extends Equatable {
  const ObjectSalesman({
    required this.id,
    this.nickTrade,
    this.nameCompany,
    this.document,
    this.active = true,
    this.aliqKickback,
    this.kickbackProduct = false,
    this.flexValue = 0,
  });

  /// Id do colaborador promovido (= tb_collaborator.id = tb_entity.id —
  /// herança por PK). No POST vai no body; na edição vai na URL.
  final int id;

  /// Identificação do colaborador — SOMENTE exibição (JOIN da API).
  final String? nickTrade;
  final String? nameCompany;
  final String? document;

  final bool    active;

  /// Percentual de comissão (0–100) — null = sem comissão definida.
  final double? aliqKickback;
  final bool    kickbackProduct;
  final double  flexValue;

  factory ObjectSalesman.fromJson(Map<String, dynamic> json) =>
      ObjectSalesman(
        id:              (json['id'] as num).toInt(),
        nickTrade:       json['nickTrade'] as String?,
        nameCompany:     json['nameCompany'] as String?,
        document:        json['document'] as String?,
        active:          (json['active'] as String?) == 'S',
        aliqKickback:    jsonDouble(json['aliqKickback']),
        kickbackProduct: (json['kickbackProduct'] as String?) == 'S',
        flexValue:       jsonDouble(json['flexValue']) ?? 0,
      );

  /// Campos do papel (salesmen.dto.ts) — a identificação NUNCA viaja.
  Map<String, dynamic> _roleJson() => {
        'active':          active ? 'S' : 'N',
        'aliqKickback':    aliqKickback,
        'kickbackProduct': kickbackProduct ? 'S' : 'N',
        'flexValue':       flexValue,
      };

  /// Body do POST (promoção — D1): [id] = colaborador escolhido no lookup.
  Map<String, dynamic> toCreateJson() => {'id': id, ..._roleJson()};

  /// Body do PUT: só os campos do papel (o id vai na URL).
  Map<String, dynamic> toUpdateJson() => _roleJson();

  /// Wrapper `Function()` no anulável permite LIMPAR (() => null).
  ObjectSalesman copyWith({
    bool? active,
    double? Function()? aliqKickback,
    bool? kickbackProduct,
    double? flexValue,
  }) =>
      ObjectSalesman(
        id:          id,
        nickTrade:   nickTrade,
        nameCompany: nameCompany,
        document:    document,
        active:      active ?? this.active,
        aliqKickback:
            aliqKickback != null ? aliqKickback() : this.aliqKickback,
        kickbackProduct: kickbackProduct ?? this.kickbackProduct,
        flexValue:       flexValue ?? this.flexValue,
      );

  @override
  List<Object?> get props => [
        id, nickTrade, nameCompany, document, active, aliqKickback,
        kickbackProduct, flexValue,
      ];
}
