import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

import '../domain/object_entity_fiscal.dart';

/// Busca de entidade por documento (Fase 3 Entidade Única, decisões 3, 9 e
/// 10): GET /api/entities/by-document — serve o PREFILL do cadastro na
/// CRIAÇÃO (ao sair do campo CPF/CNPJ com documento válido). É só UX: a
/// resolução definitiva acontece DENTRO da transação do salvar na API — o
/// app NUNCA envia entityId.
///
/// Vive em app/shared/entity porque é consumida por todos os cadastros da
/// cadeia fiscal (institutions, customers, ... — regra de promoção). Bind
/// no Module de quem usa.
class EntityByDocumentResult extends Equatable {
  const EntityByDocumentResult({
    required this.found,
    this.entity,
    this.roles = const [],
  });

  final bool found;

  /// Cadeia completa (entity + fiscal + 3 listas) — null se não achou.
  final ObjectEntityFiscal? entity;

  /// Papéis existentes ("institution", "customer", ...) — SÓ INFORMATIVOS.
  final List<String> roles;

  factory EntityByDocumentResult.fromJson(Map<String, dynamic> json) =>
      EntityByDocumentResult(
        found: json['found'] as bool? ?? false,
        entity: json['entity'] != null
            ? ObjectEntityFiscal.fromChainJson(
                json['entity'] as Map<String, dynamic>)
            : null,
        roles: (json['roles'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      );

  @override
  List<Object?> get props => [found, entity, roles];
}

abstract class EntityByDocumentDatasource {
  /// [personType] 'F' (CPF) ou 'J' (CNPJ); [doc] SEM máscara.
  /// personType 'N' não tem busca (não há chave para deduplicar).
  Future<EntityByDocumentResult> byDocument({
    required String personType,
    required String doc,
  });
}

class EntityByDocumentDatasourceImpl implements EntityByDocumentDatasource {
  const EntityByDocumentDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<EntityByDocumentResult> byDocument({
    required String personType,
    required String doc,
  }) async {
    final json = await client.get(
        '/api/entities/by-document?personType=$personType'
        '&doc=${Uri.encodeComponent(doc)}');
    return EntityByDocumentResult.fromJson(
        json['data'] as Map<String, dynamic>? ?? const {});
  }
}
