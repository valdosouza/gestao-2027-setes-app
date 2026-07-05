import 'package:equatable/equatable.dart';

import 'institution_option.dart';

/// Resultado do login (workflow do prompt, seção Autenticação):
/// - 1 institution  → [token] preenchido, direto para a home
/// - N institutions → [selectionToken] + [institutions] para a tela de escolha
class AuthSession extends Equatable {
  const AuthSession({
    this.token,
    this.selectionToken,
    this.institutions = const [],
  });

  final String? token;
  final String? selectionToken;
  final List<InstitutionOption> institutions;

  bool get needsSelection => selectionToken != null;

  @override
  List<Object?> get props => [token, selectionToken, institutions];
}
