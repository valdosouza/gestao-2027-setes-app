import 'package:dartz/dartz.dart';

import '../../../error/failure.dart';
import '../../domain/entity/auth_session.dart';
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
}
