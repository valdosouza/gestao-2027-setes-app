import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/object_institution.dart';
import '../../domain/repository/institution_repository.dart';
import '../datasource/institution_datasource.dart';

class InstitutionRepositoryImpl implements InstitutionRepository {
  const InstitutionRepositoryImpl({required this.datasource});

  final InstitutionDatasource datasource;

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() run) async {
    try {
      return Right(await run());
    } on Failure catch (failure) {
      return Left(failure);
    } catch (err) {
      return Left(Failure(message: err.toString()));
    }
  }

  @override
  Future<Either<Failure, List<InstitutionListItem>>> getList(String filter) =>
      _guard(() => datasource.getList(filter));

  @override
  Future<Either<Failure, ObjectInstitution>> get(int id) =>
      _guard(() => datasource.get(id));

  @override
  Future<Either<Failure, int>> post(ObjectInstitution institution) =>
      _guard(() => datasource.post(institution));

  @override
  Future<Either<Failure, Unit>> put(ObjectInstitution institution) =>
      _guard(() async {
        await datasource.put(institution);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> delete(int id) => _guard(() async {
        await datasource.delete(id);
        return unit;
      });
}
