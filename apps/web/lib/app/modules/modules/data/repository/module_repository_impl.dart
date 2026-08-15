import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/module_entity.dart';
import '../../domain/repository/module_repository.dart';
import '../datasource/module_datasource.dart';

class ModuleRepositoryImpl implements ModuleRepository {
  const ModuleRepositoryImpl({required this.datasource});

  final ModuleDatasource datasource;

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
  Future<Either<Failure, PagedResult<ModuleEntity>>> getList(String filter,
          {int page = 1, int? pageSize}) =>
      _guard(() => datasource.getList(filter, page: page, pageSize: pageSize));

  @override
  Future<Either<Failure, List<ModuleInterfaceOption>>> interfaceOptions() =>
      _guard(datasource.interfaceOptions);

  @override
  Future<Either<Failure, int>> post(ModuleEntity module) =>
      _guard(() => datasource.post(module));

  @override
  Future<Either<Failure, Unit>> put(ModuleEntity module) => _guard(() async {
        await datasource.put(module);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> delete(int id) => _guard(() async {
        await datasource.delete(id);
        return unit;
      });
}
