import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/service_order_fiscal_entity.dart';
import '../repository/service_order_nfse_repository.dart';

/// "Transmitir notas sem NFS-e", 1º passo — D-F145 (= Q-F153 (a), Valdo
/// 2026-10-13): a lista é FOTOGRAFADA na confirmação — todas as páginas da
/// nfse-api (`interfaceKey=service-orders`, filtro do SERVIDOR), até
/// [fiscalBatchMaxNotes]; o resto fica para o próximo lote. Página que falha
/// no meio = falha (uma lista pela metade enganaria a confirmação).
class ServiceOrderFiscalPendingList {
  const ServiceOrderFiscalPendingList({required this.repository, this.pageSize = 100});

  final ServiceOrderNfseRepository repository;
  final int pageSize;

  Future<Either<Failure, List<ServiceOrderFiscalPending>>> call() async {
    final all = <ServiceOrderFiscalPending>[];
    final seen = <int>{};
    // garantia de PROGRESSO (F2B-ADV-05): `total` mentiroso com a mesma página
    // de volta lia até `pageCount` (10⁷ GETs) — página sem NENHUMA nota nova
    // encerra, e nunca mais páginas que o teto pede (+1 de folga)
    final maxPages = (fiscalBatchMaxNotes / pageSize).ceil() + 1;
    for (var page = 1; all.length < fiscalBatchMaxNotes && page <= maxPages; page++) {
      final result = await repository.pending(page: page, pageSize: pageSize);
      final failure = result.fold<Failure?>((f) => f, (_) => null);
      if (failure != null) return Left(failure);
      final paged = result.getOrElse(() => const PagedResult.empty());
      var fresh = 0;
      for (final p in paged.items) {
        // nota que "andou" de página entre duas leituras não entra duas vezes
        if (seen.add(p.invoiceId)) {
          all.add(p);
          fresh++;
        }
      }
      if (paged.items.isEmpty || fresh == 0 || page >= paged.pageCount) break;
    }
    return Right(all.length > fiscalBatchMaxNotes ? all.sublist(0, fiscalBatchMaxNotes) : all);
  }
}
