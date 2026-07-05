import 'package:dartz/dartz.dart';

import '../../../error/failure.dart';
import '../entity/auth_session.dart';

/// domain nunca importa de data ou presentation (decisão 12).
abstract class AuthRepository {
  Future<Either<Failure, AuthSession>> login(String email, String password);

  Future<Either<Failure, String>> selectInstitution(
    String selectionToken,
    int institutionId,
  );
}
