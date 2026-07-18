import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/object_customer.dart';
import '../repository/customer_repository.dart';

/// Lista os Clientes da institution do usuário (filtro por nome/fantasia).
class CustomerGetlist {
  const CustomerGetlist({required this.repository});

  final CustomerRepository repository;

  Future<Either<Failure, List<CustomerListItem>>> call(String filter) =>
      repository.getList(filter);
}
