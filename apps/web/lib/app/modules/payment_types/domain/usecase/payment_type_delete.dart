import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/payment_type_repository.dart';

class PaymentTypeDelete {
  const PaymentTypeDelete({required this.repository});

  final PaymentTypeRepository repository;

  Future<Either<Failure, Unit>> call(int id) => repository.delete(id);
}
