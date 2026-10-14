import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entity/service_order_fiscal_entity.dart';
import '../../domain/repository/service_order_nfse_repository.dart';
import '../datasource/service_order_nfse_datasource.dart';

class ServiceOrderNfseRepositoryImpl implements ServiceOrderNfseRepository {
  const ServiceOrderNfseRepositoryImpl({required this.datasource});

  final ServiceOrderNfseDatasource datasource;

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() run) async {
    try {
      return Right(await run());
    } on NetworkFailure catch (failure) {
      // D-F185 (= Q-F193 (a), Valdo 2026-10-13 — R11-SOC-05 = R11-ADV-04): sem resposta da nfse-api = a frase NEUTRA (rede, proxy ou
      // tempo — no app WEB a página 502/503/504 do proxy sem CORS também chega aqui), a MESMA da linha do lote (D-F181): o aviso dos
      // atos fiscais e a falha da voz na seção "No fisco". Só nas chamadas à nfse-api; o tipo (NetworkFailure) e o ref seguem
      return Left(NetworkFailure(message: 'forms.serviceOrder.fiscalNoResponse', detail: failure.supportRef));
    } on Failure catch (failure) {
      return Left(failure);
    } catch (err) {
      // tipo trocado / campo nulo na resposta: falha técnica do catálogo (o texto
      // cru do Dart vai só para o supportRef — F2B-ADV-12); num ATO fiscal é
      // desfecho DESCONHECIDO (isUnknownAuthorityOutcome)
      return Left(invalidResponseFailure(err, service: 'nfse-api'));
    }
  }

  @override
  Future<Either<Failure, ServiceOrderFiscalView>> getView(int invoiceId) =>
      _guard(() => datasource.getView(invoiceId));

  @override
  Future<Either<Failure, ServiceOrderTransmitResult>> transmit(int invoiceId) =>
      _guard(() => datasource.transmit(invoiceId));

  @override
  Future<Either<Failure, ServiceOrderFiscalRefreshResult>> refresh(int invoiceId) =>
      _guard(() => datasource.refresh(invoiceId));

  @override
  Future<Either<Failure, ServiceOrderFiscalReconfirmResult>> reconfirm(int invoiceId) =>
      _guard(() => datasource.reconfirm(invoiceId));

  @override
  Future<Either<Failure, ServiceOrderFiscalCancelResult>> cancel(int invoiceId, String reason) =>
      _guard(() => datasource.cancel(invoiceId, reason));

  @override
  Future<Either<Failure, String>> xml(int invoiceId) => _guard(() => datasource.xml(invoiceId));

  @override
  Future<Either<Failure, String>> danfse(int invoiceId) => _guard(() => datasource.danfse(invoiceId));

  @override
  Future<Either<Failure, PagedResult<ServiceOrderFiscalPending>>> pending({int page = 1, int pageSize = 100}) =>
      _guard(() => datasource.pending(page: page, pageSize: pageSize));
}
