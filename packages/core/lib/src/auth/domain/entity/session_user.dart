import 'package:equatable/equatable.dart';

/// Usuário logado (GET /api/core/me) — exibido no UserBadge da home.
class SessionUser extends Equatable {
  const SessionUser({
    required this.userId,
    required this.name,
    required this.role,
    required this.institutionId,
    this.institutionName,
    this.context,
  });

  final int userId;
  final String name;
  final String role;
  final int institutionId;
  final String? institutionName;

  /// Estado de sessão derivado (decisão 17 do Framework de Configurações,
  /// ex.: isSalesman) — re-hidrata o SessionContext do app no refresh.
  final Map<String, dynamic>? context;

  /// Perfil com poder de administração (super OU admin da institution).
  bool get isAdmin => role == 'super' || role == 'admin';

  @override
  List<Object?> get props =>
      [userId, name, role, institutionId, institutionName, context];
}
