import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_entity.dart';
import '../repository/service_repository.dart';

/// Carrega o serviço COMPLETO (GET /:id) para edição — a lista não traz
/// plano financeiro, flags, observação nem a grade de preços.
class ServiceGet {
  const ServiceGet({required this.repository});

  final ServiceRepository repository;

  Future<Either<Failure, ServiceFull>> call(int id) => repository.getById(id);
}
