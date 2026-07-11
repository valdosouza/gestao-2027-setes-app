import 'package:core/core.dart';

import '../../domain/entity/state_entity.dart';

/// Datasource remoto de Estado: /api/super/states na setes-api.
/// Acesso exclusivo para role='super' (guard isSuper() no backend).
abstract class StateDatasource {
  Future<List<StateEntity>> getList(String filter);
  Future<int> post(StateEntity state);
  Future<void> put(StateEntity state);
  Future<void> delete(int id);
}

class StateDatasourceImpl implements StateDatasource {
  const StateDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<List<StateEntity>> getList(String filter) async {
    final query = filter.isNotEmpty ? '?filter=${Uri.encodeComponent(filter)}' : '';
    final json = await client.get('/api/super/states$query');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => StateEntity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// O id é o código IBGE da UF informado pelo usuário — a API devolve 409
  /// se o código já existir (mesmo excluído logicamente).
  @override
  Future<int> post(StateEntity state) async {
    final json = await client.post('/api/super/states', {
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
    await client.put('/api/super/states/${state.id}', {
      'tbCountryId':  state.tbCountryId,
      'abbreviation': state.abbreviation,
      'name':         state.name,
      'aliquota':     state.aliquota,
    });
  }

  @override
  Future<void> delete(int id) async {
    await client.delete('/api/super/states/$id');
  }
}
