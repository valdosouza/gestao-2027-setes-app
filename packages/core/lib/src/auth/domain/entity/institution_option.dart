import 'package:equatable/equatable.dart';

/// Uma institution à qual o usuário está vinculado
/// (resposta do POST /auth/login quando N > 1).
class InstitutionOption extends Equatable {
  const InstitutionOption({
    required this.institutionId,
    required this.schemaName,
    required this.name,
    this.profile,
  });

  final int institutionId;
  final String schemaName;
  final String name;
  final String? profile;

  @override
  List<Object?> get props => [institutionId, schemaName, name, profile];
}
