import 'package:core/core.dart';

import '../../domain/entity/country_entity.dart';

/// Datasource remoto de País: /api/countries na setes-api.
/// Acesso exclusivo para role='super' (guard isSuper() no backend).
abstract class CountryDatasource {
  /// Página da lista (paginação D3): [pageSize] null deixa a API resolver a
  /// config page_size do usuário (D4).
  Future<PagedResult<CountryEntity>> getList(String filter,
      {int page = 1, int? pageSize});
  Future<int> post(CountryEntity country);
  Future<void> put(CountryEntity country);
  Future<void> delete(int id);
}

class CountryDatasourceImpl implements CountryDatasource {
  const CountryDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<PagedResult<CountryEntity>> getList(String filter,
      {int page = 1, int? pageSize}) async {
    final params = [
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'page=$page',
      if (pageSize != null) 'pageSize=$pageSize',
    ];
    final json = await client.get('/api/countries?${params.join('&')}');
    return PagedResult.fromJson(json, CountryEntity.fromJson);
  }

  /// O id é o código BACEN informado pelo usuário — a API devolve 409 se o
  /// código já existir (mesmo excluído logicamente).
  @override
  Future<int> post(CountryEntity country) async {
    final json = await client.post('/api/countries', {
      'id':   country.id,
      'name': country.name,
    });
    return (json['data']['id'] as num).toInt();
  }

  @override
  Future<void> put(CountryEntity country) async {
    await client.put('/api/countries/${country.id}', {'name': country.name});
  }

  @override
  Future<void> delete(int id) async {
    await client.delete('/api/countries/$id');
  }
}
