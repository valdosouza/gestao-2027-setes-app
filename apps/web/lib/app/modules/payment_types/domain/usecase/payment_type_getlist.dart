import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/payment_type_entity.dart';
import '../repository/payment_type_repository.dart';

class PaymentTypeGetlist {
  const PaymentTypeGetlist({required this.repository});

  final PaymentTypeRepository repository;

  Future<Either<Failure, List<LinkedPaymentType>>> call() =>
      repository.getList();
}
