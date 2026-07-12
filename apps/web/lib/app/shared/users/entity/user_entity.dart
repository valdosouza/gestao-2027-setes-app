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
    this.kind,
  });

  factory UserListItem.fromJson(Map<String, dynamic> json) => UserListItem(
        id:     (json['id'] as num).toInt(),
        name:   json['name'] as String?,
        email:  json['email'] as String?,
        active: json['active'] == 'S',
        kind:   json['kind'] as String?,
      );

  final int id;
  final String? name;
  final String? email;
  final bool active;

  /// Perfil do vínculo com o institution do filtro (aba do Estabelecimento).
  final String? kind;
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

/// Um privilégio do catálogo da interface + concessão ao usuário
/// (ACL — workflow 2026-07-12).
class UserPrivilegeGrant {
  const UserPrivilegeGrant({
    required this.privilegeId,
    this.description,
    this.granted = false,
  });

  factory UserPrivilegeGrant.fromJson(Map<String, dynamic> json) =>
      UserPrivilegeGrant(
        privilegeId: (json['privilegeId'] as num).toInt(),
        description: json['description'] as String?,
        granted:     json['granted'] == 'S',
      );

  final int privilegeId;
  final String? description;
  final bool granted;

  UserPrivilegeGrant copyWith({bool? granted}) => UserPrivilegeGrant(
        privilegeId: privilegeId,
        description: description,
        granted: granted ?? this.granted,
      );
}

/// Interface CONTRATADA pelo institution alvo + privilégios do catálogo
/// com a concessão ao usuário (tela de Privilégios de Acesso).
class UserInterfacePrivileges {
  const UserInterfacePrivileges({
    required this.interfaceId,
    this.description,
    this.i18nKey,
    this.groupDefault,
    this.moduleNames,
    this.privileges = const [],
  });

  factory UserInterfacePrivileges.fromJson(Map<String, dynamic> json) =>
      UserInterfacePrivileges(
        interfaceId:  (json['interfaceId'] as num).toInt(),
        description:  json['description'] as String?,
        i18nKey:      json['i18nKey'] as String?,
        groupDefault: json['groupDefault'] as String?,
        moduleNames:  json['moduleNames'] as String?,
        privileges: (json['privileges'] as List<dynamic>? ?? [])
            .map((e) => UserPrivilegeGrant.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final int interfaceId;
  final String? description;
  final String? i18nKey;
  final String? groupDefault;

  /// Módulos do cliente que contêm a interface — filtro da tela.
  final String? moduleNames;
  final List<UserPrivilegeGrant> privileges;

  UserInterfacePrivileges copyWith({List<UserPrivilegeGrant>? privileges}) =>
      UserInterfacePrivileges(
        interfaceId: interfaceId,
        description: description,
        i18nKey: i18nKey,
        groupDefault: groupDefault,
        moduleNames: moduleNames,
        privileges: privileges ?? this.privileges,
      );
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
