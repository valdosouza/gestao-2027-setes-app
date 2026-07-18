import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/object_customer.dart';
import '../repository/customer_repository.dart';

/// Atualiza o Cliente (cascade da cadeia + tb_customer na API).
class CustomerPut {
  const CustomerPut({required this.repository});

  final CustomerRepository repository;

  Future<Either<Failure, Unit>> call(ObjectCustomer customer) =>
      repository.put(customer);
}
