/// Entidades do cadastro de Usuário — COMPARTILHADAS (regra de promoção:
/// usadas pelo módulo users E pela aba Usuários do Estabelecimento,
/// workflow 2026-07-12). O cadastro grava a cadeia do LOGIN: tb_entity +
/// tb_user (senha MD5 no backend) + tb_mailing grupo 2 (email de login) +
/// vínculos tb_institution_has_user (sem vínculo ativo o login devolve 403).
library;

/// Linha da pesquisa (GET /api/users).
class UserListItem {
  const UserListItem({
    required this.id,
    this.name,
    this.email,
    this.active = true,
  });

  factory UserListItem.fromJson(Map<String, dynamic> json) => UserListItem(
        id:     (json['id'] as num).toInt(),
        name:   json['name'] as String?,
        email:  json['email'] as String?,
        active: json['active'] == 'S',
      );

  final int id;
  final String? name;
  final String? email;
  final bool active;
}

/// Usuário completo (GET /api/users/:id) + payload do POST/PUT.
/// [password] é SÓ de envio (a API nunca devolve a senha):
/// null no PUT = mantém a atual.
class UserEntity {
  const UserEntity({
    this.id,
    required this.nameCompany,
    required this.nickTrade,
    required this.email,
    this.password,
    this.active = true,
  });

  factory UserEntity.fromJson(Map<String, dynamic> json) => UserEntity(
        id:          (json['id'] as num).toInt(),
        nameCompany: json['nameCompany'] as String? ?? '',
        nickTrade:   json['nickTrade'] as String? ?? '',
        email:       json['email'] as String? ?? '',
        active:      json['active'] == 'S',
      );

  final int? id;
  final String nameCompany;
  final String nickTrade;
  final String email;
  final String? password;
  final bool active;

  Map<String, dynamic> toJson() => {
        'nameCompany': nameCompany,
        'nickTrade':   nickTrade,
        'email':       email,
        if (password != null && password!.isNotEmpty) 'password': password,
        'active':      active ? 'S' : 'N',
      };
}

/// Linha da seção Estabelecimentos: catálogo + situação do vínculo
/// (kind = perfil na institution, vira o role do JWT).
class UserInstitutionGrant {
  const UserInstitutionGrant({
    required this.institutionId,
    this.name,
    this.schemaName = '',
    this.kind,
    this.granted = false,
  });

  factory UserInstitutionGrant.fromJson(Map<String, dynamic> json) =>
      UserInstitutionGrant(
        institutionId: (json['institutionId'] as num).toInt(),
        name:          json['name'] as String?,
        schemaName:    json['schemaName'] as String? ?? '',
        kind:          json['kind'] as String?,
        granted:       json['granted'] == 'S',
      );

  final int institutionId;
  final String? name;
  final String schemaName;
  final String? kind;
  final bool granted;

  UserInstitutionGrant copyWith({String? kind, bool? granted}) =>
      UserInstitutionGrant(
        institutionId: institutionId,
        name: name,
        schemaName: schemaName,
        kind: kind ?? this.kind,
        granted: granted ?? this.granted,
      );
}
