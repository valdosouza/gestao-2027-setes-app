import 'package:dartz/dartz.dart';

import '../../../error/failure.dart';
import '../entity/auth_session.dart';
import '../entity/session_user.dart';

/// domain nunca importa de data ou presentation (decisão 12).
abstract class AuthRepository {
  Future<Either<Failure, AuthSession>> login(String email, String password);

  Future<Either<Failure, String>> selectInstitution(
    String selectionToken,
    int institutionId,
  );

  Future<Either<Failure, SessionUser>> getMe();

  Future<Either<Failure, Unit>> recoveryPassword(String email);

  Future<Either<Failure, Unit>> changePassword(String email, String code, String newPassword);
}
