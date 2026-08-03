import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/salesman_repository.dart';

/// Soft delete LIVRE (D4): a carteira (tb_customer.tb_salesman_id) fica
/// como histórico; o lookup deixa de oferecer o excluído.
class SalesmanDelete {
  const SalesmanDelete({required this.repository});

  final SalesmanRepository repository;

  Future<Either<Failure, Unit>> call(int id) => repository.delete(id);
}
