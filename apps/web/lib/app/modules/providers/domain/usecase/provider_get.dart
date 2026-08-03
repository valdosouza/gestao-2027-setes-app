import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/object_provider.dart';
import '../repository/provider_repository.dart';

class ProviderGet {
  const ProviderGet({required this.repository});

  final ProviderRepository repository;

  Future<Either<Failure, ObjectProvider>> call(int id) => repository.get(id);
}
