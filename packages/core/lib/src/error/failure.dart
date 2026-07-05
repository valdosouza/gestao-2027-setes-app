import 'package:equatable/equatable.dart';

/// Falha de domínio (decisão 12: operações assíncronas retornam
/// `Either<Failure, T>` via dartz).
class Failure extends Equatable {
  const Failure({required this.message, this.statusCode});

  final String message;
  final int? statusCode;

  @override
  List<Object?> get props => [message, statusCode];
}

class NetworkFailure extends Failure {
  const NetworkFailure({super.message = 'Falha de conexão com o servidor'});
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({super.message = 'Sessão inválida ou expirada'})
      : super(statusCode: 401);
}
