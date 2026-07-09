import 'package:dartz/dartz.dart';

import '../../../error/failure.dart';
import '../repository/auth_repository.dart';

class RecoveryPasswordUsecase {
  const RecoveryPasswordUsecase({required this.repository});

  final AuthRepository repository;

  Future<Either<Failure, Unit>> call(String email) => repository.recoveryPassword(email);
}
