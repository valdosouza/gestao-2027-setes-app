import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_order_entity.dart';
import '../repository/service_order_repository.dart';

/// LOTE da cobrança mensal (D6/D7 da fase Primeiro Cliente): fatura as
/// ordens SELECIONADAS com as mesmas condições. A API responde 200 mesmo
/// com falhas parciais — o relatório é o resultado, não o status.
class ServiceOrderBatchInvoice {
  const ServiceOrderBatchInvoice({required this.repository});

  final ServiceOrderRepository repository;

  Future<Either<Failure, BatchInvoiceReport>> call(
          List<int> orderIds, ServiceOrderInvoiceInput input) =>
      repository.batchInvoice(orderIds, input);
}
