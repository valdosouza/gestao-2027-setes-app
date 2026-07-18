import '../../domain/entity/auth_session.dart';
import '../../domain/entity/institution_option.dart';

/// Model do POST /auth/login (contrato da Fase 2 do setes-api):
/// `{ ok, token }` OU `{ ok, select: true, selectionToken, institutions: [...] }`
class LoginResultModel extends AuthSession {
  const LoginResultModel({
    super.token,
    super.selectionToken,
    super.institutions,
    super.context,
  });

  factory LoginResultModel.fromJson(Map<String, dynamic> json) {
    if (json['select'] == true) {
      final list = (json['institutions'] as List<dynamic>? ?? [])
          .map((e) => InstitutionOptionModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return LoginResultModel(
        selectionToken: json['selectionToken'] as String?,
        institutions: list,
      );
    }
    return LoginResultModel(
      token: json['token'] as String?,
      // Estado de sessão derivado (decisão 17) — acompanha o token final.
      context: json['context'] as Map<String, dynamic>?,
    );
  }

  static LoginResultModel empty() => const LoginResultModel();
}

class InstitutionOptionModel extends InstitutionOption {
  const InstitutionOptionModel({
    required super.institutionId,
    required super.schemaName,
    required super.name,
    super.profile,
  });

  factory InstitutionOptionModel.fromJson(Map<String, dynamic> json) =>
      InstitutionOptionModel(
        institutionId: (json['institutionId'] as num?)?.toInt() ?? 0,
        schemaName: json['schemaName'] as String? ?? '',
        name: json['name'] as String? ?? '',
        profile: json['profile'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'institutionId': institutionId,
        'schemaName': schemaName,
        'name': name,
        'profile': profile,
      };
}
