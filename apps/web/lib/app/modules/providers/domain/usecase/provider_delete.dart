import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/provider_repository.dart';

class ProviderDelete {
  const ProviderDelete({required this.repository});

  final ProviderRepository repository;

  Future<Either<Failure, Unit>> call(int id) => repository.delete(id);
}
