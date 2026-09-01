import 'package:core/core.dart';

import '../../domain/entity/tax_rule_catalogs.dart';
import '../../domain/entity/tax_rule_draft.dart';
import '../../domain/entity/tax_rule_list_item.dart';

/// Datasource remoto de Regras de Tributação: /api/tax-rules na setes-api
/// (cadastro do CLIENTE — escopo por institution no JWT; flag 'tax-rules').
abstract class TaxRuleDatasource {
  /// Página da lista (paginação D3): [pageSize] null deixa a API resolver a
  /// config page_size do usuário (D4). Filtro por NCM/descrição do produto.
  Future<PagedResult<TaxRuleListItem>> getList(String filter,
      {int page = 1, int? pageSize});

  /// Regra completa (seletor + peças presentes) para a edição.
  Future<TaxRuleDraft> getById(int id);

  /// Catálogos fiscais centrais para os combos — UMA chamada na abertura
  /// do form (lookup de apoio, exceção D6).
  Future<TaxRuleCatalogs> getCatalogs();

  /// CFOPs por ALÇADA (rodada 2026-09-01): sentido + UF do destinatário
  /// determinam o 1º dígito (mesma UF do emitente = 1/5; outra UF = 2/6;
  /// EX = 3/7; UF vazia = os 3 dígitos do sentido). Alçada resolvida na
  /// API — o app não conhece a UF do emitente.
  Future<List<CatalogEntry>> getCfopOptions({
    required String direction,
    int? stateId,
    required String filter,
  });

  Future<void> post(TaxRuleDraft draft);
  Future<void> put(TaxRuleDraft draft);
  Future<void> delete(int id);
}

class TaxRuleDatasourceImpl implements TaxRuleDatasource {
  const TaxRuleDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<PagedResult<TaxRuleListItem>> getList(String filter,
      {int page = 1, int? pageSize}) async {
    final params = [
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'page=$page',
      if (pageSize != null) 'pageSize=$pageSize',
    ];
    final json = await client.get('/api/tax-rules?${params.join('&')}');
    return PagedResult.fromJson(json, TaxRuleListItem.fromJson);
  }

  @override
  Future<TaxRuleDraft> getById(int id) async {
    final json = await client.get('/api/tax-rules/$id');
    return TaxRuleDraft.fromJson(json['data'] as Map<String, dynamic>? ?? {});
  }

  @override
  Future<TaxRuleCatalogs> getCatalogs() async {
    final json = await client.get('/api/tax-rules/catalogs');
    return TaxRuleCatalogs.fromJson(
        json['data'] as Map<String, dynamic>? ?? {});
  }

  @override
  Future<List<CatalogEntry>> getCfopOptions({
    required String direction,
    int? stateId,
    required String filter,
  }) async {
    final params = [
      'direction=$direction',
      if (stateId != null) 'stateId=$stateId',
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
    ];
    final json = await client.get('/api/tax-rules/cfops?${params.join('&')}');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => CatalogEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// id = MAX+1 no backend (sem padrão externo — o app nunca manda id).
  @override
  Future<void> post(TaxRuleDraft draft) async {
    await client.post('/api/tax-rules', draft.toJson());
  }

  @override
  Future<void> put(TaxRuleDraft draft) async {
    await client.put('/api/tax-rules/${draft.id}', draft.toJson());
  }

  @override
  Future<void> delete(int id) async {
    await client.delete('/api/tax-rules/$id');
  }
}
