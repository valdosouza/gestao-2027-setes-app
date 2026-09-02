import 'package:core/core.dart';

import '../../domain/entity/price_list_entity.dart';

/// Datasource remoto de Tabelas de Preço: /api/price-lists na setes-api
/// (módulo gêmeo — escopo por institution vem do JWT).
abstract class PriceListDatasource {
  /// Página da lista (paginação obrigatória — filtro REMOTO por descrição):
  /// [pageSize] null deixa a API resolver a config page_size do usuário.
  Future<PagedResult<PriceListEntity>> getList(String filter,
      {int page = 1, int? pageSize});

  /// Tabela de preço para edição.
  Future<PriceListEntity> getById(int id);

  /// Cria a tabela — devolve o id (MAX+1 da API).
  Future<int> post(PriceListInput input);

  /// Atualiza a tabela.
  Future<void> put(int id, PriceListInput input);

  /// Soft delete.
  Future<void> delete(int id);
}

class PriceListDatasourceImpl implements PriceListDatasource {
  const PriceListDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<PagedResult<PriceListEntity>> getList(String filter,
      {int page = 1, int? pageSize}) async {
    final params = [
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'page=$page',
      if (pageSize != null) 'pageSize=$pageSize',
    ];
    final json = await client.get('/api/price-lists?${params.join('&')}');
    return PagedResult.fromJson(json, PriceListEntity.fromJson);
  }

  @override
  Future<PriceListEntity> getById(int id) async {
    final json = await client.get('/api/price-lists/$id');
    return PriceListEntity.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<int> post(PriceListInput input) async {
    final json = await client.post('/api/price-lists', input.toJson());
    final data = json['data'] as Map<String, dynamic>? ?? const {};
    return jsonInt(data['id']) ?? 0;
  }

  @override
  Future<void> put(int id, PriceListInput input) async {
    await client.put('/api/price-lists/$id', input.toJson());
  }

  @override
  Future<void> delete(int id) async {
    await client.delete('/api/price-lists/$id');
  }
}
