import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/object_customer.dart';
import '../../domain/repository/customer_repository.dart';
import '../datasource/customer_datasource.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  const CustomerRepositoryImpl({required this.datasource});

  final CustomerDatasource datasource;

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
  Future<Either<Failure, List<CustomerListItem>>> getList(String filter) =>
      _guard(() => datasource.getList(filter));

  @override
  Future<Either<Failure, ObjectCustomer>> get(int id) =>
      _guard(() => datasource.get(id));

  @override
  Future<Either<Failure, CustomerPostResult>> post(ObjectCustomer customer) =>
      _guard(() => datasource.post(customer));

  @override
  Future<Either<Failure, Unit>> put(ObjectCustomer customer) =>
      _guard(() async {
        await datasource.put(customer);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> delete(int id) => _guard(() async {
        await datasource.delete(id);
        return unit;
      });
}
