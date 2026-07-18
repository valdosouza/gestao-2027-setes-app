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
    this.context,
  });

  final String? token;
  final String? selectionToken;
  final List<InstitutionOption> institutions;

  /// Bloco `context` da resposta do login (decisão 17 do Framework de
  /// Configurações — estado de sessão derivado, ex.: isSalesman). Só
  /// acompanha o token FINAL; o SessionContext do app é preenchido a partir
  /// dele (ou re-hidratado via GET /api/core/me no refresh).
  final Map<String, dynamic>? context;

  bool get needsSelection => selectionToken != null;

  @override
  List<Object?> get props => [token, selectionToken, institutions, context];
}
