import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/payment_type_entity.dart';
import '../repository/payment_type_repository.dart';

class PaymentTypePost {
  const PaymentTypePost({required this.repository});

  final PaymentTypeRepository repository;

  Future<Either<Failure, PaymentTypePostResult>> call({
    int? catalogId,
    String? description,
    String? idNfce,
    required PaymentTypeLinkAttrs attrs,
  }) =>
      repository.post(
        catalogId: catalogId,
        description: description,
        idNfce: idNfce,
        attrs: attrs,
      );
}
