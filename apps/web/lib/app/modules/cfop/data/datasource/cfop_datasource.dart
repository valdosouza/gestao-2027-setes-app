import 'package:core/core.dart';

import '../../domain/entity/cfop_entity.dart';

/// Datasource remoto de CFOP: /api/cfop na setes-api.
/// Acesso exclusivo para role='super' (guard isSuper() no backend).
abstract class CfopDatasource {
  Future<List<CfopEntity>> getList(String filter);
  Future<void> post(CfopEntity cfop);
  Future<void> put(CfopEntity cfop);
  Future<void> delete(String id);
}

class CfopDatasourceImpl implements CfopDatasource {
  const CfopDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<List<CfopEntity>> getList(String filter) async {
    final query = filter.isNotEmpty ? '?filter=${Uri.encodeComponent(filter)}' : '';
    final json = await client.get('/api/cfop$query');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => CfopEntity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// O código é digitado pelo usuário (409 se já existir — inclui excluídos).
  @override
  Future<void> post(CfopEntity cfop) async {
    await client.post('/api/cfop', cfop.toCreateJson());
  }

  @override
  Future<void> put(CfopEntity cfop) async {
    await client.put('/api/cfop/${cfop.id}', cfop.toJson());
  }

  @override
  Future<void> delete(String id) async {
    await client.delete('/api/cfop/$id');
  }
}
