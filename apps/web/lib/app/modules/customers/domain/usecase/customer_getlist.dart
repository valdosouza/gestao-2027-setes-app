import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/object_customer.dart';
import '../repository/customer_repository.dart';

/// Lista os Clientes da institution do usuário (filtro por nome/fantasia),
/// uma PÁGINA por vez (paginação D3).
class CustomerGetlist {
  const CustomerGetlist({required this.repository});

  final CustomerRepository repository;

  Future<Either<Failure, PagedResult<CustomerListItem>>> call(String filter,
          {int page = 1, int? pageSize}) =>
      repository.getList(filter, page: page, pageSize: pageSize);
}
