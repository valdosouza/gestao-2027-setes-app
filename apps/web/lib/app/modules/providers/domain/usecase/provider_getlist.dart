import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/object_provider.dart';
import '../repository/provider_repository.dart';

/// Lista os Fornecedores da institution do usuário, uma PÁGINA por vez
/// (paginação D3).
class ProviderGetlist {
  const ProviderGetlist({required this.repository});

  final ProviderRepository repository;

  Future<Either<Failure, PagedResult<ProviderListItem>>> call(String filter,
          {int page = 1, int? pageSize}) =>
      repository.getList(filter, page: page, pageSize: pageSize);
}
