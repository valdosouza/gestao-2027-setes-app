import 'package:core/core.dart';

import '../../domain/entity/service_tax_rule_entity.dart';

/// Lookup de apoio do form da regra — itens ATIVOS da Lista de Serviços
/// (LC 116), SÓ LEITURA, endpoint do próprio módulo
/// (/api/service-tax-rules/service-list). É o que a page pode consumir
/// direto (padrão StateLookupDatasource): a page NUNCA toca o
/// ServiceTaxRuleDatasource principal (escrita passa por usecase/bloc).
/// Promover para app/shared/lookup quando um segundo módulo precisar.
abstract class ServiceTaxRuleLookupDatasource {
  Future<List<ServiceListLookup>> serviceList(String filter);
}

class ServiceTaxRuleLookupDatasourceImpl
    implements ServiceTaxRuleLookupDatasource {
  const ServiceTaxRuleLookupDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<List<ServiceListLookup>> serviceList(String filter) async {
    final query =
        filter.isNotEmpty ? '?filter=${Uri.encodeComponent(filter)}' : '';
    final json = await client.get('/api/service-tax-rules/service-list$query');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => ServiceListLookup.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
