import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

/// Parceria v2 — ANGARIAÇÃO do cliente (decisões do Valdo D1–D7,
/// Infra-IA/prompts/Parceria.md): a parceria vive na aba "Parceria" do
/// cadastro de CLIENTE. Espelho da tb_partnership FLAT: 1 linha por
/// colaborador envolvido (colaborador × percentual × ativo). Regras:
/// percentual > 0 e ≤ 90; soma dos percentuais ATIVOS ≤ 90 (os 10% da
/// Setes são fixos e implícitos); lista vazia = sem parceria.

/// Percentual pt-BR com 2 casas ('45,50') — o '%' fica na chave i18n.
String partnershipRate(double value) =>
    value.toStringAsFixed(2).replaceAll('.', ',');

/// Parceiro da angariação (linha da tb_partnership): colaborador que
/// trouxe e/ou atende o cliente × percentual combinado.
class CustomerPartnershipPartner extends Equatable {
  const CustomerPartnershipPartner({
    required this.collaboratorId,
    this.collaboratorName,
    this.rate = 0,
    this.active = true,
  });

  final int     collaboratorId;

  /// Nome do colaborador (JOIN da API — só exibição).
  final String? collaboratorName;

  /// Percentual do parceiro (> 0 e ≤ 90; soma dos ATIVOS ≤ 90).
  final double  rate;

  /// 'S'/'N' na API — parceiro suspenso não conta na soma dos ativos.
  final bool    active;

  factory CustomerPartnershipPartner.fromJson(Map<String, dynamic> json) =>
      CustomerPartnershipPartner(
        collaboratorId:   jsonInt(json['collaboratorId']) ?? 0,
        collaboratorName: json['collaboratorName'] as String?,
        rate:             jsonDouble(json['rate']) ?? 0,
        active:           (json['active'] as String? ?? 'S') == 'S',
      );

  /// Body do PUT — a API recebe a lista COMPLETA e sincroniza por
  /// colaborador (nome fica de fora: é derivado do JOIN).
  Map<String, dynamic> toJson() => {
        'collaboratorId': collaboratorId,
        'rate':           rate,
        'active':         active ? 'S' : 'N',
      };

  @override
  List<Object?> get props => [collaboratorId, collaboratorName, rate, active];
}

/// Item do lookup de colaboradores (/api/collaborators — projeção local:
/// módulo nunca importa módulo).
class CollaboratorLookupItem extends Equatable {
  const CollaboratorLookupItem({
    required this.id,
    this.nickTrade,
    this.nameCompany,
  });

  final int     id;
  final String? nickTrade;
  final String? nameCompany;

  /// Exibição: nome fantasia, senão razão social.
  String get display => nickTrade ?? nameCompany ?? '';

  factory CollaboratorLookupItem.fromJson(Map<String, dynamic> json) =>
      CollaboratorLookupItem(
        id:          jsonInt(json['id']) ?? 0,
        nickTrade:   json['nickTrade'] as String?,
        nameCompany: json['nameCompany'] as String?,
      );

  @override
  List<Object?> get props => [id, nickTrade, nameCompany];
}
