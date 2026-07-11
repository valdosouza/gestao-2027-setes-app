import 'package:core/core.dart';

import '../../domain/entity/city_entity.dart';

/// Datasource remoto de Cidade: /api/super/cities na setes-api.
/// Acesso exclusivo para role='super' (guard isSuper() no backend).
abstract class CityDatasource {
  Future<List<CityEntity>> getList(String filter);
  Future<int> post(CityEntity city);
  Future<void> put(CityEntity city);
  Future<void> delete(int id);
}

class CityDatasourceImpl implements CityDatasource {
  const CityDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<List<CityEntity>> getList(String filter) async {
    final query = filter.isNotEmpty ? '?filter=${Uri.encodeComponent(filter)}' : '';
    final json = await client.get('/api/super/cities$query');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => CityEntity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// O id é o código IBGE do município informado pelo usuário — a API
  /// devolve 409 se o código já existir (mesmo excluído logicamente).
  @override
  Future<int> post(CityEntity city) async {
    final json = await client.post('/api/super/cities', {
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
    await client.put('/api/super/cities/${city.id}', {
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
    await client.delete('/api/super/cities/$id');
  }
}
