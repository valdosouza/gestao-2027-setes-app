import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/payment_type_entity.dart';
import '../repository/payment_type_repository.dart';

class PaymentTypePut {
  const PaymentTypePut({required this.repository});

  final PaymentTypeRepository repository;

  Future<Either<Failure, Unit>> call(int id,
          {required PaymentTypeLinkAttrs attrs, String? idNfce}) =>
      repository.put(id, attrs: attrs, idNfce: idNfce);
}
