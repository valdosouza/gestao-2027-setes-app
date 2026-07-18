import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/interface_config/entity/interface_config_entity.dart';
import '../../../../shared/interface_vitrine/interface_vitrine_entity.dart';
import '../../domain/repository/interface_configs_repository.dart';
import '../datasource/interface_configs_datasource.dart';

class InterfaceConfigsRepositoryImpl implements InterfaceConfigsRepository {
  const InterfaceConfigsRepositoryImpl({required this.datasource});

  final InterfaceConfigsDatasource datasource;

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
  Future<Either<Failure, List<InterfaceVitrineEntity>>> vitrine(String filter) =>
      _guard(() => datasource.vitrine(filter));

  @override
  Future<Either<Failure, List<InterfaceConfigEntity>>> configs(int interfaceId) =>
      _guard(() => datasource.configs(interfaceId));

  @override
  Future<Either<Failure, Unit>> saveValue({
    required int interfaceId,
    required String name,
    required String? content,
    required bool asUser,
  }) =>
      _guard(() async {
        await datasource.saveValue(
          interfaceId: interfaceId,
          name: name,
          content: content,
          asUser: asUser,
        );
        return unit;
      });
}
