import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/object_establishment.dart';
import '../../domain/repository/establishment_repository.dart';
import '../datasource/establishment_datasource.dart';

class EstablishmentRepositoryImpl implements EstablishmentRepository {
  const EstablishmentRepositoryImpl({required this.datasource});

  final EstablishmentDatasource datasource;

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
  Future<Either<Failure, ObjectEstablishment>> get() =>
      _guard(() => datasource.get());

  @override
  Future<Either<Failure, ObjectEstablishment>> put(
          ObjectEstablishment establishment) =>
      _guard(() => datasource.put(establishment));
}
