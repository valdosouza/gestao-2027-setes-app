import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/object_provider.dart';
import '../repository/provider_repository.dart';

class ProviderPut {
  const ProviderPut({required this.repository});

  final ProviderRepository repository;

  Future<Either<Failure, Unit>> call(ObjectProvider provider) =>
      repository.put(provider);
}
