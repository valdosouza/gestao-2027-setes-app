import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../entity/service_order_entity.dart';
import '../repository/service_order_invoice_repository.dart';
import '../repository/service_order_nfse_repository.dart';

/// Em que passo a saga do cancelamento parou — a tela diz a coisa certa:
/// [authority] = o fisco não cancelou (ou o desfecho é desconhecido — o K
/// pode estar em voo: releia e consulte); [invoice] = a nota no ERP não foi
/// cancelada (se o fisco JÁ cancelou, o efeito fica `apply` — a tela oferece
/// "Aplicar o cancelamento na nota").
enum CancelSagaStage { authority, invoice }

class CancelSagaFailure extends Equatable {
  const CancelSagaFailure({required this.stage, required this.failure, this.authorityCancelled = false});

  final CancelSagaStage stage;
  final Failure failure;

  /// true = o fisco cancelou nesta saga e só o passo da nota falhou.
  final bool authorityCancelled;

  @override
  List<Object?> get props => [stage, failure, authorityCancelled];
}

class ServiceOrderCancelOutcome extends Equatable {
  const ServiceOrderCancelOutcome({required this.result, this.warnings = const []});

  final ServiceOrderInvoiceCancelResult result;

  /// Avisos NÃO bloqueantes do cancelamento no fisco.
  final List<String> warnings;

  @override
  List<Object?> get props => [result, warnings];
}

/// SAGA do cancelamento da nota da OS — D-F139 (= Q-F147 (a), Valdo
/// 2026-10-13): usecase de COMPOSIÇÃO sobre os DOIS repositórios (o fisco na
/// nfse-api × a nota no ERP), nunca o bloc chamando as duas APIs. Só a ORDEM
/// é do app (D-F28: o fisco fala primeiro; só com o "ok" dele o ERP é
/// chamado); quem DECIDE é a API que recebe cada ato — o PLANO (lido antes
/// pela tela) diz se [atAuthority] cabe.
///
/// Retomada por DERIVAÇÃO, nunca diário no cliente: se o passo da nota falha
/// depois do fisco ter cancelado, nada fica guardado aqui — a tela relê o
/// efeito (`apply`) e oferece "Aplicar o cancelamento na nota", que é esta
/// mesma saga com [atAuthority] = false.
class ServiceOrderCancelInvoice {
  const ServiceOrderCancelInvoice({required this.nfse, required this.invoice});

  final ServiceOrderNfseRepository nfse;
  final ServiceOrderInvoiceRepository invoice;

  Future<Either<CancelSagaFailure, ServiceOrderCancelOutcome>> call(
      int orderId, String reason, {required bool atAuthority}) async {
    var warnings = const <String>[];
    if (atAuthority) {
      final atFisco = await nfse.cancel(orderId, reason);
      final refused = atFisco.fold<Failure?>((f) => f, (r) {
        warnings = r.warnings;
        return null;
      });
      if (refused != null) return Left(CancelSagaFailure(stage: CancelSagaStage.authority, failure: refused));
    }
    final local = await invoice.cancel(orderId, reason);
    return local.fold(
      (failure) => Left(CancelSagaFailure(
          stage: CancelSagaStage.invoice, failure: failure, authorityCancelled: atAuthority)),
      (result) => Right(ServiceOrderCancelOutcome(result: result, warnings: warnings)),
    );
  }
}
