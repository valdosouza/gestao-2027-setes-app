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
    final query = filter.isNotEmpty ? '?filter=${Uri.encodeComponent(filter)}' : '';
    final json = await client.get('/api/super/states$query');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => StateLookup.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
