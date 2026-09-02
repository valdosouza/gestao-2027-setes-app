import 'package:core/core.dart';

import '../../domain/entity/service_entity.dart';

/// Datasource remoto de Serviços: /api/services na setes-api (módulo gêmeo —
/// escopo por institution vem do JWT; kind='S' é fixado pela API, D5).
/// Lookups de categoria/plano vivem em ServiceLookupDatasource (o que a
/// page consome direto); a grade do serviço NOVO nasce das tabelas de preço
/// vivas — GET /api/services/price-lists (o app fala SÓ com /api/services,
/// nunca com o endpoint do módulo vizinho).
abstract class ServiceDatasource {
  /// Página da lista (filtro REMOTO por descrição/identificador):
  /// [pageSize] null deixa a API resolver a config page_size do usuário.
  Future<PagedResult<ServiceListItem>> getList(String filter,
      {int page = 1, int? pageSize});

  /// Serviço completo (plano, flags, observação e grade de preços).
  Future<ServiceFull> getById(int id);

  /// Tabelas de preço vivas → grade vazia do serviço NOVO (priceTag null).
  Future<List<ServicePrice>> priceLists();

  /// Cria o serviço — devolve o id (MAX+1 da API).
  Future<int> post(ServiceInput input);

  /// Atualiza o serviço (grade sincronizada na mesma transação).
  Future<void> put(int id, ServiceInput input);

  /// Soft delete.
  Future<void> delete(int id);
}

class ServiceDatasourceImpl implements ServiceDatasource {
  const ServiceDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<PagedResult<ServiceListItem>> getList(String filter,
      {int page = 1, int? pageSize}) async {
    final params = [
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'page=$page',
      if (pageSize != null) 'pageSize=$pageSize',
    ];
    final json = await client.get('/api/services?${params.join('&')}');
    return PagedResult.fromJson(json, ServiceListItem.fromJson);
  }

  @override
  Future<ServiceFull> getById(int id) async {
    final json = await client.get('/api/services/$id');
    return ServiceFull.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<List<ServicePrice>> priceLists() async {
    final json = await client.get('/api/services/price-lists');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => ServicePrice.fromPriceListJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<int> post(ServiceInput input) async {
    final json = await client.post('/api/services', input.toJson());
    final data = json['data'] as Map<String, dynamic>? ?? const {};
    return jsonInt(data['id']) ?? 0;
  }

  @override
  Future<void> put(int id, ServiceInput input) async {
    await client.put('/api/services/$id', input.toJson());
  }

  @override
  Future<void> delete(int id) async {
    await client.delete('/api/services/$id');
  }
}
