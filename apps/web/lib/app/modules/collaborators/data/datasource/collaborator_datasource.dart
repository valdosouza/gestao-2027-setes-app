import 'package:core/core.dart';

import '../../domain/entity/object_collaborator.dart';

/// Datasource remoto de Colaborador: /api/collaborators na setes-api
/// (módulo gêmeo, SEM superGuard — cadastro do cliente; escopo por
/// institution vem do JWT). POST devolve { id, reused } — reused=true quando
/// a API reaproveitou uma entity existente pelo CPF/CNPJ (decisões 1 e 9).
abstract class CollaboratorDatasource {
  Future<List<CollaboratorListItem>> getList(String filter);

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
  Future<List<CollaboratorListItem>> getList(String filter) async {
    final query =
        filter.isNotEmpty ? '?filter=${Uri.encodeComponent(filter)}' : '';
    final json = await client.get('/api/collaborators$query');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => CollaboratorListItem.fromJson(e as Map<String, dynamic>))
        .toList();
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
