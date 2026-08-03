import 'package:core/core.dart';

import '../../domain/entity/city_entity.dart';

/// Datasource remoto de Cidade: /api/cities na setes-api.
/// Acesso exclusivo para role='super' (guard isSuper() no backend).
abstract class CityDatasource {
  /// Página da lista (paginação D3): [pageSize] null deixa a API resolver a
  /// config page_size do usuário (D4).
  Future<PagedResult<CityEntity>> getList(String filter,
      {int page = 1, int? pageSize});
  Future<int> post(CityEntity city);
  Future<void> put(CityEntity city);
  Future<void> delete(int id);
}

class CityDatasourceImpl implements CityDatasource {
  const CityDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<PagedResult<CityEntity>> getList(String filter,
      {int page = 1, int? pageSize}) async {
    final params = [
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'page=$page',
      if (pageSize != null) 'pageSize=$pageSize',
    ];
    final json = await client.get('/api/cities?${params.join('&')}');
    return PagedResult.fromJson(json, CityEntity.fromJson);
  }

  /// O id é o código IBGE do município informado pelo usuário — a API
  /// devolve 409 se o código já existir (mesmo excluído logicamente).
  @override
  Future<int> post(CityEntity city) async {
    final json = await client.post('/api/cities', {
      'id':         city.id,
      'tbStateId':  city.tbStateId,
      'name':       city.name,
      if (city.ibge != null) 'ibge': city.ibge,
      'aliqIss':    city.aliqIss,
      'population': city.population,
      'density':    city.density,
      'area':       city.area,
    });
    return (json['data']['id'] as num).toInt();
  }

  @override
  Future<void> put(CityEntity city) async {
    await client.put('/api/cities/${city.id}', {
      'tbStateId':  city.tbStateId,
      'name':       city.name,
      'ibge':       city.ibge,
      'aliqIss':    city.aliqIss,
      'population': city.population,
      'density':    city.density,
      'area':       city.area,
    });
  }

  @override
  Future<void> delete(int id) async {
    await client.delete('/api/cities/$id');
  }
}
