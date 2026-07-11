import 'package:core/core.dart';

import '../../domain/entity/country_entity.dart';

/// Datasource remoto de País: /api/super/countries na setes-api.
/// Acesso exclusivo para role='super' (guard isSuper() no backend).
abstract class CountryDatasource {
  Future<List<CountryEntity>> getList(String filter);
  Future<int> post(CountryEntity country);
  Future<void> put(CountryEntity country);
  Future<void> delete(int id);
}

class CountryDatasourceImpl implements CountryDatasource {
  const CountryDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<List<CountryEntity>> getList(String filter) async {
    final query = filter.isNotEmpty ? '?filter=${Uri.encodeComponent(filter)}' : '';
    final json = await client.get('/api/super/countries$query');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => CountryEntity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// O id é o código BACEN informado pelo usuário — a API devolve 409 se o
  /// código já existir (mesmo excluído logicamente).
  @override
  Future<int> post(CountryEntity country) async {
    final json = await client.post('/api/super/countries', {
      'id':   country.id,
      'name': country.name,
    });
    return (json['data']['id'] as num).toInt();
  }

  @override
  Future<void> put(CountryEntity country) async {
    await client.put('/api/super/countries/${country.id}', {'name': country.name});
  }

  @override
  Future<void> delete(int id) async {
    await client.delete('/api/super/countries/$id');
  }
}
