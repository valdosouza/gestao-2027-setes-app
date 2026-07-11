import 'package:core/core.dart';

import '../entity/country_lookup_entity.dart';

/// Lookup de Países para listas de apoio (somente leitura).
/// Consumido por qualquer módulo cujo cadastro tenha FK de país
/// (hoje: states). Bind feito no Module de quem usa.
abstract class CountryLookupDatasource {
  Future<List<CountryLookup>> list(String filter);
}

class CountryLookupDatasourceImpl implements CountryLookupDatasource {
  const CountryLookupDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<List<CountryLookup>> list(String filter) async {
    final query = filter.isNotEmpty ? '?filter=${Uri.encodeComponent(filter)}' : '';
    final json = await client.get('/api/super/countries$query');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => CountryLookup.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
