import 'package:dartz/dartz.dart';

import '../../../error/failure.dart';
import '../repository/auth_repository.dart';

class ChangePasswordUsecase {
  const ChangePasswordUsecase({required this.repository});

  final AuthRepository repository;

  Future<Either<Failure, Unit>> call(String email, String code, String newPassword) =>
      repository.changePassword(email, code, newPassword);
}
