import 'package:core/core.dart';

import '../../domain/entity/service_tax_rule_entity.dart';

/// Lookup de apoio do form da regra — itens ATIVOS da Lista de Serviços
/// (LC 116) e os DESDOBROS nacionais de um item (cTribNac — Onda 3 NFS-e),
/// SÓ LEITURA, endpoints do próprio módulo
/// (/api/service-tax-rules/service-list e /national-codes). É o que a page
/// pode consumir direto (padrão StateLookupDatasource): a page NUNCA toca o
/// ServiceTaxRuleDatasource principal (escrita passa por usecase/bloc).
/// Promover para app/shared/lookup quando um segundo módulo precisar.
abstract class ServiceTaxRuleLookupDatasource {
  Future<List<ServiceListLookup>> serviceList(String filter);

  /// Desdobros do item na tributação nacional (lookup DEPENDENTE do item —
  /// campo-lookup-fk.md item 5). 1 resultado = código derivado; N = o
  /// usuário escolhe; 0 = item sem código nacional no catálogo.
  Future<List<NationalCodeLookup>> nationalCodes(String serviceListId);
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

  @override
  Future<List<NationalCodeLookup>> nationalCodes(String serviceListId) async {
    final json = await client.get(
        '/api/service-tax-rules/national-codes?serviceListId=${Uri.encodeComponent(serviceListId)}');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => NationalCodeLookup.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
