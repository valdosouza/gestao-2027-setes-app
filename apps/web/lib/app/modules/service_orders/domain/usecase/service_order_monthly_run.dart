import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_order_entity.dart';
import '../repository/service_order_repository.dart';

/// Rotina de faturamento mensal (D8 — botão manual): abre/reusa ordens e
/// injeta itens de contrato com pró-rata; devolve o relatório por cliente.
class ServiceOrderMonthlyRun {
  const ServiceOrderMonthlyRun({required this.repository});

  final ServiceOrderRepository repository;

  Future<Either<Failure, MonthlyRunReport>> call(int year, int month) =>
      repository.monthlyRun(year, month);
}
