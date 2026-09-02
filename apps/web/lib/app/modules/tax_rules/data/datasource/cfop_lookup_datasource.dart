import 'package:core/core.dart';

import '../../domain/entity/tax_rule_catalogs.dart';

/// Lookup de CFOPs por ALÇADA (rodada 2026-09-01) — SÓ LEITURA, endpoint do
/// próprio módulo (/api/tax-rules/cfops). Sentido + UF do destinatário
/// determinam o 1º dígito (mesma UF do emitente = 1/5; outra UF = 2/6;
/// EX = 3/7; UF vazia = os 3 dígitos do sentido) — resolvido na API, o app
/// não conhece a UF do emitente. É o que a page consome direto (padrão
/// StateLookupDatasource): a page nunca toca o TaxRuleDatasource principal.
abstract class CfopLookupDatasource {
  Future<List<CatalogEntry>> search({
    required String direction,
    int? stateId,
    required String filter,
  });
}

class CfopLookupDatasourceImpl implements CfopLookupDatasource {
  const CfopLookupDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<List<CatalogEntry>> search({
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
}
