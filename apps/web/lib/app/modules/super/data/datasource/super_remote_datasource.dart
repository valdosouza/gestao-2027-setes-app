import 'package:core/core.dart';

import '../../domain/entity/geo_entities.dart';

/// Datasource remoto do módulo Super: chama /api/super/* na setes-api.
/// Acesso exclusivo para role='super' (validado no backend — guard isSuper()).
class SuperRemoteDatasource {
  const SuperRemoteDatasource({required this.client});

  final ApiClient client;

  // =====================================================================
  // Country
  // =====================================================================

  Future<List<CountryEntity>> listCountries(String filter) async {
    final path = '/api/super/countries${filter.isNotEmpty ? '?filter=${Uri.encodeComponent(filter)}' : ''}';
    final json = await client.get(path);
    final data = json['data'] as List<dynamic>? ?? [];
    return data.map((e) => CountryEntity.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<CountryEntity> getCountry(int id) async {
    final json = await client.get('/api/super/countries/$id');
    return CountryEntity.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// O id é o código mundial do país (padrão BACEN — ex.: Brasil 1058),
  /// informado pelo usuário na inclusão; NÃO é sequencial (decisão 2026-07-10).
  /// A API devolve 409 se o código já existir (mesmo excluído).
  Future<int> createCountry({required int id, required String name}) async {
    final json = await client.post('/api/super/countries', {'id': id, 'name': name});
    return (json['data']['id'] as num).toInt();
  }

  Future<void> updateCountry(int id, String name) async {
    await client.put('/api/super/countries/$id', {'name': name});
  }

  Future<void> deleteCountry(int id) async {
    await client.delete('/api/super/countries/$id');
  }

  // =====================================================================
  // State
  // =====================================================================

  Future<List<StateEntity>> listStates(String filter, {int? countryId}) async {
    final params = <String>[];
    if (filter.isNotEmpty) params.add('filter=${Uri.encodeComponent(filter)}');
    if (countryId != null) params.add('countryId=$countryId');
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    final json = await client.get('/api/super/states$query');
    final data = json['data'] as List<dynamic>? ?? [];
    return data.map((e) => StateEntity.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<StateEntity> getState(int id) async {
    final json = await client.get('/api/super/states/$id');
    return StateEntity.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<int> createState({
    required int tbCountryId,
    required String abbreviation,
    required String name,
    double? aliquota,
  }) async {
    final json = await client.post('/api/super/states', {
      'tbCountryId':  tbCountryId,
      'abbreviation': abbreviation,
      'name':         name,
      if (aliquota != null) 'aliquota': aliquota,
    });
    return (json['data']['id'] as num).toInt();
  }

  Future<void> updateState(int id, {
    required int tbCountryId,
    required String abbreviation,
    required String name,
    double? aliquota,
  }) async {
    await client.put('/api/super/states/$id', {
      'tbCountryId':  tbCountryId,
      'abbreviation': abbreviation,
      'name':         name,
      'aliquota':     aliquota,
    });
  }

  Future<void> deleteState(int id) async {
    await client.delete('/api/super/states/$id');
  }

  // =====================================================================
  // City
  // =====================================================================

  Future<List<CityEntity>> listCities(String filter, {int? stateId}) async {
    final params = <String>[];
    if (filter.isNotEmpty) params.add('filter=${Uri.encodeComponent(filter)}');
    if (stateId != null) params.add('stateId=$stateId');
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    final json = await client.get('/api/super/cities$query');
    final data = json['data'] as List<dynamic>? ?? [];
    return data.map((e) => CityEntity.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<CityEntity> getCity(int id) async {
    final json = await client.get('/api/super/cities/$id');
    return CityEntity.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<int> createCity({
    required int tbStateId,
    required String name,
    String? ibge,
    double aliqIss = 0,
    int population = 0,
    double density = 0,
    double area = 0,
  }) async {
    final json = await client.post('/api/super/cities', {
      'tbStateId':  tbStateId,
      'name':       name,
      if (ibge != null) 'ibge': ibge,
      'aliqIss':    aliqIss,
      'population': population,
      'density':    density,
      'area':       area,
    });
    return (json['data']['id'] as num).toInt();
  }

  Future<void> updateCity(int id, {
    required int tbStateId,
    required String name,
    String? ibge,
    double aliqIss = 0,
    int population = 0,
    double density = 0,
    double area = 0,
  }) async {
    await client.put('/api/super/cities/$id', {
      'tbStateId':  tbStateId,
      'name':       name,
      'ibge':       ibge,
      'aliqIss':    aliqIss,
      'population': population,
      'density':    density,
      'area':       area,
    });
  }

  Future<void> deleteCity(int id) async {
    await client.delete('/api/super/cities/$id');
  }
}
