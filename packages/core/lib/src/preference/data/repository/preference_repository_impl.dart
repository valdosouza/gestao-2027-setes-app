import 'package:dartz/dartz.dart';

import '../../../error/failure.dart';
import '../../domain/repository/preference_repository.dart';
import '../datasource/preference_remote_datasource.dart';

class PreferenceRepositoryImpl implements PreferenceRepository {
  const PreferenceRepositoryImpl({required this.datasource});

  final PreferenceRemoteDatasource datasource;

  @override
  Future<Either<Failure, Map<String, String>>> getAll() async {
    try {
      return Right(await datasource.getAll());
    } on Failure catch (f) {
      return Left(f);
    } catch (_) {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> save(String key, String value) async {
    try {
      await datasource.save(key, value);
      return const Right(unit);
    } on Failure catch (f) {
      return Left(f);
    } catch (_) {
      return const Left(NetworkFailure());
    }
  }
}
