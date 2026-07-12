import 'package:core/core.dart';

import '../entity/user_entity.dart';

/// Datasource remoto de Usuário: /api/users na setes-api — COMPARTILHADO
/// (regra de promoção: módulo users + aba Usuários do Estabelecimento).
/// Bind GLOBAL no AppModule. Guard da API: adminGuard — super opera
/// qualquer institution; admin do cliente é FORÇADO à do JWT.
abstract class UserDatasource {
  /// [institutionId] restringe aos vinculados (aba do Estabelecimento);
  /// para o admin do cliente a API força a institution do JWT.
  Future<List<UserListItem>> getList(String filter, {int? institutionId});
  Future<UserEntity> get(int id);

  /// A API gera o id (MAX+1 da tb_entity) e aplica o MD5 da senha.
  /// [institutionId]+[kind] criam o vínculo na MESMA transação (workflow
  /// 2026-07-12 — primeiro admin do cliente nasce já vinculado).
  Future<int> post(UserEntity user, {int? institutionId, String? kind});
  Future<void> put(UserEntity user);
  Future<void> delete(int id);

  /// Vínculos multi-institution (EXCLUSIVO do super — 403 para admin).
  Future<List<UserInstitutionGrant>> getInstitutions(int userId);

  /// Sincroniza: concede a lista (com kind), revoga (soft) as demais.
  Future<void> setInstitutions(
      int userId, List<({int institutionId, String kind})> links);
}

class UserDatasourceImpl implements UserDatasource {
  const UserDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<List<UserListItem>> getList(String filter, {int? institutionId}) async {
    final params = [
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      if (institutionId != null) 'institutionId=$institutionId',
    ].join('&');
    final json = await client.get('/api/users${params.isEmpty ? '' : '?$params'}');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => UserListItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<UserEntity> get(int id) async {
    final json = await client.get('/api/users/$id');
    return UserEntity.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<int> post(UserEntity user, {int? institutionId, String? kind}) async {
    final json = await client.post('/api/users', {
      ...user.toJson(),
      if (institutionId != null) 'institutionId': institutionId,
      if (kind != null) 'kind': kind,
    });
    return (json['data']['id'] as num).toInt();
  }

  @override
  Future<void> put(UserEntity user) async {
    await client.put('/api/users/${user.id}', user.toJson());
  }

  @override
  Future<void> delete(int id) async {
    await client.delete('/api/users/$id');
  }

  @override
  Future<List<UserInstitutionGrant>> getInstitutions(int userId) async {
    final json = await client.get('/api/users/$userId/institutions');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => UserInstitutionGrant.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> setInstitutions(
      int userId, List<({int institutionId, String kind})> links) async {
    await client.put('/api/users/$userId/institutions', {
      'links': [
        for (final link in links)
          {'institutionId': link.institutionId, 'kind': link.kind},
      ],
    });
  }
}
