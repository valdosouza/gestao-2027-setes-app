import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/object_provider.dart';
import '../repository/provider_repository.dart';

class ProviderPost {
  const ProviderPost({required this.repository});

  final ProviderRepository repository;

  Future<Either<Failure, ProviderPostResult>> call(ObjectProvider provider) =>
      repository.post(provider);
}
