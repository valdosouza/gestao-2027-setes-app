import 'package:core/core.dart';

import '../../domain/entity/service_entity.dart';

/// Lookups de apoio do form de Serviço (categoria e plano financeiro) —
/// SÓ LEITURA, endpoints do próprio módulo (/api/services/*). É o que a
/// page pode consumir direto (padrão StateLookupDatasource): a page NUNCA
/// toca o ServiceDatasource principal (escrita passa por usecase/bloc).
/// Promover para app/shared/lookup quando um segundo módulo precisar.
abstract class ServiceLookupDatasource {
  Future<List<ServiceLookup>> categories(String filter);
  Future<List<ServiceLookup>> financialPlans(String filter);
}

class ServiceLookupDatasourceImpl implements ServiceLookupDatasource {
  const ServiceLookupDatasourceImpl({required this.client});

  final ApiClient client;

  Future<List<ServiceLookup>> _lookup(String path, String filter) async {
    final query =
        filter.isNotEmpty ? '?filter=${Uri.encodeComponent(filter)}' : '';
    final json = await client.get('/api/services/$path$query');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => ServiceLookup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<ServiceLookup>> categories(String filter) =>
      _lookup('categories', filter);

  @override
  Future<List<ServiceLookup>> financialPlans(String filter) =>
      _lookup('financial-plans', filter);
}
