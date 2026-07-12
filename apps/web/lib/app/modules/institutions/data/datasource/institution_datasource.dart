import 'package:core/core.dart';

import '../../domain/entity/object_institution.dart';

/// Datasource remoto de Estabelecimento: /api/institutions na setes-api.
/// Acesso exclusivo para role='super' (guard isSuper() no backend).
///
/// O POST absorveu o onboarding (decisão do Valdo, 2026-07-11): a API cria
/// a cadeia fiscal em transação única, provisiona o schema do cliente
/// (migrações) e só então ativa a institution.
abstract class InstitutionDatasource {
  Future<List<InstitutionListItem>> getList(String filter);

  /// Objeto COMPLETO (entity + fiscal + 3 listas + institution).
  Future<ObjectInstitution> get(int id);
  Future<int> post(ObjectInstitution institution);
  Future<void> put(ObjectInstitution institution);
  Future<void> delete(int id);
}

class InstitutionDatasourceImpl implements InstitutionDatasource {
  const InstitutionDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<List<InstitutionListItem>> getList(String filter) async {
    final query =
        filter.isNotEmpty ? '?filter=${Uri.encodeComponent(filter)}' : '';
    final json = await client.get('/api/institutions$query');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => InstitutionListItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ObjectInstitution> get(int id) async {
    final json = await client.get('/api/institutions/$id');
    return ObjectInstitution.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<int> post(ObjectInstitution institution) async {
    final json = await client.post(
        '/api/institutions', institution.toJson(creating: true));
    return (json['data']['id'] as num).toInt();
  }

  @override
  Future<void> put(ObjectInstitution institution) async {
    await client.put('/api/institutions/${institution.id}',
        institution.toJson(creating: false));
  }

  @override
  Future<void> delete(int id) async {
    await client.delete('/api/institutions/$id');
  }
}
