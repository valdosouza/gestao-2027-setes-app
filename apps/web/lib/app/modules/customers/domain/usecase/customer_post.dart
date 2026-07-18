import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/object_customer.dart';
import '../repository/customer_repository.dart';

/// Cria o Cliente. A API resolve o reuso da entity pelo CPF/CNPJ dentro da
/// transação (Fase 3, decisão 9) — o retorno informa se reaproveitou.
class CustomerPost {
  const CustomerPost({required this.repository});

  final CustomerRepository repository;

  Future<Either<Failure, CustomerPostResult>> call(ObjectCustomer customer) =>
      repository.post(customer);
}
