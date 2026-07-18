import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/customer_repository.dart';

/// Exclui o PAPEL de cliente (soft delete — a cadeia entity permanece para
/// os demais papéis/schemas, Fase 3).
class CustomerDelete {
  const CustomerDelete({required this.repository});

  final CustomerRepository repository;

  Future<Either<Failure, Unit>> call(int id) => repository.delete(id);
}
