import 'package:core/core.dart';

import '../../../../shared/lookup/entity/role_lookup_entity.dart';
import '../../domain/entity/object_salesman.dart';

/// Datasource remoto de Vendedor: /api/salesmen na setes-api (módulo gêmeo
/// — cadastro do cliente; escopo por institution vem do JWT).
///
/// Onda 2 (D1): o "novo vendedor" nasce do lookup de COLABORADORES
/// ([collaboratorLookup]) — a precedência Collaborator→Salesman morre por
/// construção; o POST leva o id do colaborador promovido.
abstract class SalesmanDatasource {
  /// Página da lista (paginação D3): [pageSize] null deixa a API resolver a
  /// config page_size do usuário (D4).
  Future<PagedResult<SalesmanListItem>> getList(String filter,
      {int page = 1, int? pageSize});

  /// Identificação do colaborador (readonly) + campos do papel.
  Future<ObjectSalesman> get(int id);

  /// Colaboradores da institution — origem da promoção (D1). Lista de
  /// apoio (lookup FK): NÃO pagina.
  Future<List<RoleLookup>> collaboratorLookup(String filter);

  /// Devolve o id do papel criado (= id do colaborador promovido).
  Future<int> post(ObjectSalesman salesman);
  Future<void> put(ObjectSalesman salesman);
  Future<void> delete(int id);
}

class SalesmanDatasourceImpl implements SalesmanDatasource {
  const SalesmanDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<PagedResult<SalesmanListItem>> getList(String filter,
      {int page = 1, int? pageSize}) async {
    final params = [
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'page=$page',
      if (pageSize != null) 'pageSize=$pageSize',
    ];
    final json = await client.get('/api/salesmen?${params.join('&')}');
    return PagedResult.fromJson(json, SalesmanListItem.fromJson);
  }

  @override
  Future<ObjectSalesman> get(int id) async {
    final json = await client.get('/api/salesmen/$id');
    return ObjectSalesman.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<List<RoleLookup>> collaboratorLookup(String filter) async {
    final query =
        filter.isNotEmpty ? '?filter=${Uri.encodeComponent(filter)}' : '';
    final json =
        await client.get('/api/salesmen/collaborator-lookup$query');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => RoleLookup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<int> post(ObjectSalesman salesman) async {
    final json = await client.post('/api/salesmen', salesman.toCreateJson());
    final data = json['data'] as Map<String, dynamic>? ?? const {};
    return (data['id'] as num).toInt();
  }

  @override
  Future<void> put(ObjectSalesman salesman) async {
    await client.put('/api/salesmen/${salesman.id}', salesman.toUpdateJson());
  }

  @override
  Future<void> delete(int id) async {
    await client.delete('/api/salesmen/$id');
  }
}
