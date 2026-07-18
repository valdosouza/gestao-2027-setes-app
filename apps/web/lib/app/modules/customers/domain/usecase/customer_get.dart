import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/object_customer.dart';
import '../repository/customer_repository.dart';

/// Busca o Cliente COMPLETO (cadeia fiscal inteira) para edição.
class CustomerGet {
  const CustomerGet({required this.repository});

  final CustomerRepository repository;

  Future<Either<Failure, ObjectCustomer>> call(int id) => repository.get(id);
}
