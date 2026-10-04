import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/search/search_criterion.dart';
import '../entity/payment_type_entity.dart';
import '../repository/payment_type_repository.dart';

/// Lista as Formas de Pagamento vinculadas à institution (filtro REMOTO —
/// D7), uma PÁGINA por vez (paginação D3).
class PaymentTypeGetlist {
  const PaymentTypeGetlist({required this.repository});

  final PaymentTypeRepository repository;

  Future<Either<Failure, PagedResult<LinkedPaymentType>>> call(String filter,
          {int page = 1,
          int? pageSize,
          SearchCriteriaValues criteria = SearchCriteriaValues.empty}) =>
      repository.getList(filter,
          page: page, pageSize: pageSize, criteria: criteria);
}
