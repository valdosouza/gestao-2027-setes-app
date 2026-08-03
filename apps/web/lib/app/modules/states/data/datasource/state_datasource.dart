import 'package:core/core.dart';

import '../../domain/entity/state_entity.dart';

/// Datasource remoto de Estado: /api/states na setes-api.
/// Acesso exclusivo para role='super' (guard isSuper() no backend).
abstract class StateDatasource {
  /// Página da lista (paginação D3): [pageSize] null deixa a API resolver a
  /// config page_size do usuário (D4).
  Future<PagedResult<StateEntity>> getList(String filter,
      {int page = 1, int? pageSize});
  Future<int> post(StateEntity state);
  Future<void> put(StateEntity state);
  Future<void> delete(int id);
}

class StateDatasourceImpl implements StateDatasource {
  const StateDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<PagedResult<StateEntity>> getList(String filter,
      {int page = 1, int? pageSize}) async {
    final params = [
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'page=$page',
      if (pageSize != null) 'pageSize=$pageSize',
    ];
    final json = await client.get('/api/states?${params.join('&')}');
    return PagedResult.fromJson(json, StateEntity.fromJson);
  }

  /// O id é o código IBGE da UF informado pelo usuário — a API devolve 409
  /// se o código já existir (mesmo excluído logicamente).
  @override
  Future<int> post(StateEntity state) async {
    final json = await client.post('/api/states', {
      'id':           state.id,
      'tbCountryId':  state.tbCountryId,
      'abbreviation': state.abbreviation,
      'name':         state.name,
      if (state.aliquota != null) 'aliquota': state.aliquota,
    });
    return (json['data']['id'] as num).toInt();
  }

  @override
  Future<void> put(StateEntity state) async {
    await client.put('/api/states/${state.id}', {
      'tbCountryId':  state.tbCountryId,
      'abbreviation': state.abbreviation,
      'name':         state.name,
      'aliquota':     state.aliquota,
    });
  }

  @override
  Future<void> delete(int id) async {
    await client.delete('/api/states/$id');
  }
}
