import 'package:core/core.dart';

import '../../domain/entity/object_collaborator.dart';

/// Datasource remoto de Colaborador: /api/collaborators na setes-api
/// (módulo gêmeo, SEM superGuard — cadastro do cliente; escopo por
/// institution vem do JWT). POST devolve { id, reused } — reused=true quando
/// a API reaproveitou uma entity existente pelo CPF/CNPJ (decisões 1 e 9).
abstract class CollaboratorDatasource {
  /// Página da lista (paginação D3): [pageSize] null deixa a API resolver a
  /// config page_size do usuário (D4).
  Future<PagedResult<CollaboratorListItem>> getList(String filter,
      {int page = 1, int? pageSize});

  /// Objeto COMPLETO (entity + fiscal + 3 listas + collaborator).
  Future<ObjectCollaborator> get(int id);
  Future<CollaboratorPostResult> post(ObjectCollaborator collaborator);
  Future<void> put(ObjectCollaborator collaborator);
  Future<void> delete(int id);
}

class CollaboratorDatasourceImpl implements CollaboratorDatasource {
  const CollaboratorDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<PagedResult<CollaboratorListItem>> getList(String filter,
      {int page = 1, int? pageSize}) async {
    final params = [
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'page=$page',
      if (pageSize != null) 'pageSize=$pageSize',
    ];
    final json = await client.get('/api/collaborators?${params.join('&')}');
    return PagedResult.fromJson(json, CollaboratorListItem.fromJson);
  }

  @override
  Future<ObjectCollaborator> get(int id) async {
    final json = await client.get('/api/collaborators/$id');
    return ObjectCollaborator.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<CollaboratorPostResult> post(ObjectCollaborator collaborator) async {
    final json = await client.post('/api/collaborators', collaborator.toJson());
    final data = json['data'] as Map<String, dynamic>? ?? const {};
    return CollaboratorPostResult(
      id:     (data['id'] as num).toInt(),
      reused: data['reused'] as bool? ?? false,
    );
  }

  @override
  Future<void> put(ObjectCollaborator collaborator) async {
    await client.put(
        '/api/collaborators/${collaborator.id}', collaborator.toJson());
  }

  @override
  Future<void> delete(int id) async {
    await client.delete('/api/collaborators/$id');
  }
}
