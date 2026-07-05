import 'package:dartz/dartz.dart';

import '../../../error/failure.dart';
import '../entity/auth_session.dart';
import '../repository/auth_repository.dart';

class LoginUsecase {
  const LoginUsecase({required this.repository});

  final AuthRepository repository;

  Future<Either<Failure, AuthSession>> call(String email, String password) =>
      repository.login(email, password);
}
