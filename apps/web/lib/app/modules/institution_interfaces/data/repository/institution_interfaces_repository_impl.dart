import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/client_institution_entity.dart';
import '../../domain/repository/institution_interfaces_repository.dart';
import '../datasource/institution_interfaces_datasource.dart';

class InstitutionInterfacesRepositoryImpl implements InstitutionInterfacesRepository {
  const InstitutionInterfacesRepositoryImpl({required this.datasource});

  final InstitutionInterfacesDatasource datasource;

  @override
  Future<Either<Failure, PagedResult<ClientInstitutionEntity>>> list(String filter,
      {int page = 1, int? pageSize}) async {
    try {
      return Right(await datasource.list(filter, page: page, pageSize: pageSize));
    } on Failure catch (failure) {
      return Left(failure);
    } catch (err) {
      return Left(Failure(message: err.toString()));
    }
  }
}
