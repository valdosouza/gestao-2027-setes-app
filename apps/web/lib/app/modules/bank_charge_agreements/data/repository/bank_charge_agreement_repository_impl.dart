import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/bank_charge_agreement_entity.dart';
import '../../domain/repository/bank_charge_agreement_repository.dart';
import '../datasource/bank_charge_agreement_datasource.dart';

class BankChargeAgreementRepositoryImpl
    implements BankChargeAgreementRepository {
  const BankChargeAgreementRepositoryImpl({required this.datasource});

  final BankChargeAgreementDatasource datasource;

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
  Future<Either<Failure, PagedResult<BankChargeAgreementListItem>>> getList(
          String filter,
          {int page = 1, int? pageSize}) =>
      _guard(() => datasource.getList(filter, page: page, pageSize: pageSize));

  @override
  Future<Either<Failure, BankChargeAgreementFull>> getById(int id) =>
      _guard(() => datasource.getById(id));

  @override
  Future<Either<Failure, int>> post(BankChargeAgreementInput input) =>
      _guard(() => datasource.post(input));

  @override
  Future<Either<Failure, Unit>> put(int id, BankChargeAgreementInput input) =>
      _guard(() async {
        await datasource.put(id, input);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> delete(int id) => _guard(() async {
        await datasource.delete(id);
        return unit;
      });
}
