import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/object_customer.dart';

/// Contrato do repositório de Cliente (decisão 12: Either via dartz).
abstract class CustomerRepository {
  Future<Either<Failure, PagedResult<CustomerListItem>>> getList(String filter,
      {int page, int? pageSize});
  Future<Either<Failure, ObjectCustomer>> get(int id);
  Future<Either<Failure, CustomerPostResult>> post(ObjectCustomer customer);
  Future<Either<Failure, Unit>> put(ObjectCustomer customer);
  Future<Either<Failure, Unit>> delete(int id);
}
