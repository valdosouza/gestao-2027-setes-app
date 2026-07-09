import 'package:dartz/dartz.dart';

import '../../../error/failure.dart';
import '../../domain/entity/auth_session.dart';
import '../../domain/entity/session_user.dart';
import '../../domain/repository/auth_repository.dart';
import '../datasource/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({required this.datasource});

  final AuthRemoteDatasource datasource;

  @override
  Future<Either<Failure, AuthSession>> login(String email, String password) async {
    try {
      return Right(await datasource.login(email, password));
    } on Failure catch (f) {
      return Left(f);
    } catch (_) {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, String>> selectInstitution(
    String selectionToken,
    int institutionId,
  ) async {
    try {
      return Right(await datasource.selectInstitution(selectionToken, institutionId));
    } on Failure catch (f) {
      return Left(f);
    } catch (_) {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, SessionUser>> getMe() async {
    try {
      return Right(await datasource.getMe());
    } on Failure catch (f) {
      return Left(f);
    } catch (_) {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> recoveryPassword(String email) async {
    try {
      await datasource.recoveryPassword(email);
      return const Right(unit);
    } on Failure catch (f) {
      return Left(f);
    } catch (_) {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> changePassword(
      String email, String code, String newPassword) async {
    try {
      await datasource.changePassword(email, code, newPassword);
      return const Right(unit);
    } on Failure catch (f) {
      return Left(f);
    } catch (_) {
      return const Left(NetworkFailure());
    }
  }
}
