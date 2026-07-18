import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/payment_type_entity.dart';

/// Contrato do repositório de Formas de Pagamento (Either/dartz).
abstract class PaymentTypeRepository {
  Future<Either<Failure, List<LinkedPaymentType>>> getList();
  Future<Either<Failure, List<PaymentTypeCatalogItem>>> catalog(String filter);
  Future<Either<Failure, PaymentTypePostResult>> post({
    int? catalogId,
    String? description,
    String? idNfce,
    required PaymentTypeLinkAttrs attrs,
  });
  Future<Either<Failure, Unit>> put(int id,
      {required PaymentTypeLinkAttrs attrs, String? idNfce});
  Future<Either<Failure, Unit>> delete(int id);
}
