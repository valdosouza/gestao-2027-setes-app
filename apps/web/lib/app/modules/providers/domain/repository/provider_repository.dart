import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/search/search_criterion.dart';
import '../entity/object_provider.dart';

/// Contrato do repositório de Fornecedor (Either/dartz).
abstract class ProviderRepository {
  Future<Either<Failure, PagedResult<ProviderListItem>>> getList(String filter,
      {int page, int? pageSize, SearchCriteriaValues criteria});
  Future<Either<Failure, ObjectProvider>> get(int id);
  Future<Either<Failure, ProviderPostResult>> post(ObjectProvider provider);
  Future<Either<Failure, Unit>> put(ObjectProvider provider);
  Future<Either<Failure, Unit>> delete(int id);
}
