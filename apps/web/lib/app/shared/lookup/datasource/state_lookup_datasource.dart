import 'package:core/core.dart';

import '../entity/state_lookup_entity.dart';

/// Lookup de Estados para listas de apoio (somente leitura).
/// Consumido por qualquer módulo cujo cadastro tenha FK de estado
/// (hoje: cities). Bind feito no Module de quem usa.
abstract class StateLookupDatasource {
  Future<List<StateLookup>> list(String filter);
}

class StateLookupDatasourceImpl implements StateLookupDatasource {
  const StateLookupDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<List<StateLookup>> list(String filter) async {
    // Lookup NÃO pagina (D6), mas o envelope agora traz pageSize default 25
    // — pageSize=100 mantém o alcance da lista de apoio.
    final params = [
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'pageSize=100',
    ];
    final json = await client.get('/api/states?${params.join('&')}');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => StateLookup.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
