import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/payment_type_entity.dart';
import '../../domain/repository/payment_type_repository.dart';
import '../datasource/payment_type_datasource.dart';

class PaymentTypeRepositoryImpl implements PaymentTypeRepository {
  const PaymentTypeRepositoryImpl({required this.datasource});

  final PaymentTypeDatasource datasource;

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
  Future<Either<Failure, List<LinkedPaymentType>>> getList() =>
      _guard(() => datasource.getList());

  @override
  Future<Either<Failure, List<PaymentTypeCatalogItem>>> catalog(String filter) =>
      _guard(() => datasource.catalog(filter));

  @override
  Future<Either<Failure, PaymentTypePostResult>> post({
    int? catalogId,
    String? description,
    String? idNfce,
    required PaymentTypeLinkAttrs attrs,
  }) =>
      _guard(() => datasource.post(
            catalogId: catalogId,
            description: description,
            idNfce: idNfce,
            attrs: attrs,
          ));

  @override
  Future<Either<Failure, Unit>> put(int id,
          {required PaymentTypeLinkAttrs attrs, String? idNfce}) =>
      _guard(() async {
        await datasource.put(id, attrs: attrs, idNfce: idNfce);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> delete(int id) => _guard(() async {
        await datasource.delete(id);
        return unit;
      });
}
