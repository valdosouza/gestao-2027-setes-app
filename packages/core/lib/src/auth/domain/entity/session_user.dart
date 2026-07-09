import 'package:equatable/equatable.dart';

/// Usuário logado (GET /api/core/me) — exibido no UserBadge da home.
class SessionUser extends Equatable {
  const SessionUser({
    required this.userId,
    required this.name,
    required this.role,
    required this.institutionId,
    this.institutionName,
  });

  final int userId;
  final String name;
  final String role;
  final int institutionId;
  final String? institutionName;

  @override
  List<Object?> get props => [userId, name, role, institutionId, institutionName];
}
