import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/field_config/entity/field_config_entity.dart';
import '../../../../shared/interface_vitrine/interface_vitrine_entity.dart';
import '../../domain/repository/interface_fields_repository.dart';
import '../datasource/interface_fields_datasource.dart';

class InterfaceFieldsRepositoryImpl implements InterfaceFieldsRepository {
  const InterfaceFieldsRepositoryImpl({required this.datasource});

  final InterfaceFieldsDatasource datasource;

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
  Future<Either<Failure, List<FieldConfigEntity>>> fields(int interfaceId) =>
      _guard(() => datasource.fields(interfaceId));

  @override
  Future<Either<Failure, Unit>> saveField({
    required int interfaceId,
    required String fieldName,
    String? caption,
    bool required = false,
    String? mask,
  }) =>
      _guard(() async {
        await datasource.saveField(
          interfaceId: interfaceId,
          fieldName: fieldName,
          caption: caption,
          required: required,
          mask: mask,
        );
        return unit;
      });
}
