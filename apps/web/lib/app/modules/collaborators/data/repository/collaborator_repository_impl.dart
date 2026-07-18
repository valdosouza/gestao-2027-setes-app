import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/object_collaborator.dart';
import '../../domain/repository/collaborator_repository.dart';
import '../datasource/collaborator_datasource.dart';

class CollaboratorRepositoryImpl implements CollaboratorRepository {
  const CollaboratorRepositoryImpl({required this.datasource});

  final CollaboratorDatasource datasource;

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
  Future<Either<Failure, List<CollaboratorListItem>>> getList(String filter) =>
      _guard(() => datasource.getList(filter));

  @override
  Future<Either<Failure, ObjectCollaborator>> get(int id) =>
      _guard(() => datasource.get(id));

  @override
  Future<Either<Failure, CollaboratorPostResult>> post(
          ObjectCollaborator collaborator) =>
      _guard(() => datasource.post(collaborator));

  @override
  Future<Either<Failure, Unit>> put(ObjectCollaborator collaborator) =>
      _guard(() async {
        await datasource.put(collaborator);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> delete(int id) => _guard(() async {
        await datasource.delete(id);
        return unit;
      });
}
