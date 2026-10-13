import 'package:core/core.dart';

import '../entity/service_order_fiscal_entity.dart';
import '../repository/service_order_nfse_repository.dart';

/// "Transmitir notas sem NFS-e", 2º passo — o lote roda NO APP (a nfse-api não
/// tem lote no servidor): D-F145 (= Q-F153 (a), Valdo 2026-10-13).
///
/// - UMA nota por vez, na ordem da lista fotografada (nunca em paralelo — o
///   fisco e a trava da nota agradecem);
/// - erro DA NOTA (422 recusa do fisco, 409 da regra, desfecho desconhecido)
///   vira linha do relatório e o lote SEGUE;
/// - erro SISTÊMICO PARA o lote (as notas seguintes entram como "não
///   tentadas"): sessão (401), licença/privilégio (403), certificado/
///   habilitação (`FISCAL_CERT_*`, `FISCAL_ISSUER_MISSING`), virada pendente
///   (`FISCAL_CUTOVER_PENDING`), cofre sem chave
///   (`FISCAL_MASTER_KEY_UNAVAILABLE`) e [maxConsecutiveUnknown] desfechos
///   desconhecidos SEGUIDOS (o fisco fora não se insiste nota a nota).
class ServiceOrderFiscalTransmitBatch {
  const ServiceOrderFiscalTransmitBatch({required this.repository, this.maxConsecutiveUnknown = 3});

  final ServiceOrderNfseRepository repository;
  final int maxConsecutiveUnknown;

  /// Erro que vale para TODAS as notas — continuar seria repetir a mesma recusa.
  static bool isSystemic(Failure failure) {
    final code = failure.code ?? '';
    return failure is UnauthorizedFailure ||
        failure.statusCode == 403 ||
        code.startsWith('FISCAL_CERT_') ||
        _systemicCodes.contains(code);
  }

  /// Valem para TODAS as notas do estabelecimento — continuar só empilha
  /// tentativas (e queima nDPS + voz F permanente em cada nota). Gates da F2b
  /// (F2B-SOC-03/ADV-02): o fisco recusou o A1 no mTLS, a cadeia do servidor do
  /// fisco não é confiável, o cadastro do emitente está incompleto; D-F148: o
  /// serviço não reconheceu a sessão; configuração do app torta.
  static const _systemicCodes = {
    'FISCAL_ISSUER_MISSING',
    FiscalCodes.cutoverPending,
    'FISCAL_MASTER_KEY_UNAVAILABLE',
    'FISCAL_AUTHORITY_AUTH_FAILED',
    'FISCAL_AUTHORITY_CHAIN_UNTRUSTED',
    'FISCAL_EMITTER_INCOMPLETE',
    ClientFailureCodes.sessionNotAccepted,
    ClientFailureCodes.configuration,
  };

  /// [shouldStop] = a tela fechou (bloc fechado): para sem relatório.
  Future<FiscalTransmitBatchReport> call(List<int> orderIds, {bool Function()? shouldStop}) async {
    final ids = orderIds.toSet().toList();
    final rows = <FiscalTransmitBatchRow>[];
    Failure? stoppedBy;
    var unknownInARow = 0;
    var i = 0;
    for (; i < ids.length; i++) {
      if (shouldStop?.call() ?? false) break;
      final id = ids[i];
      final result = await repository.transmit(id);
      final failure = result.fold<Failure?>((f) => f, (_) => null);
      if (failure == null) {
        unknownInARow = 0;
        rows.add(FiscalTransmitBatchRow(orderId: id, ok: true));
        continue;
      }
      // D-F168: o desfecho DESCONHECIDO é linha própria ("incerta — consulte"), nunca "recusada"
      rows.add(FiscalTransmitBatchRow(orderId: id, ok: false, code: failure.code ?? '', message: failure.message,
          unknown: isUnknownAuthorityOutcome(failure), supportRef: failure.supportRef ?? ''));
      if (isSystemic(failure)) {
        stoppedBy = failure;
        i++;
        break;
      }
      unknownInARow = isUnknownAuthorityOutcome(failure) ? unknownInARow + 1 : 0;
      if (unknownInARow >= maxConsecutiveUnknown) {
        stoppedBy = failure;
        i++;
        break;
      }
    }
    if (stoppedBy != null) {
      for (final id in ids.sublist(i)) {
        rows.add(FiscalTransmitBatchRow.aborted(orderId: id, message: stoppedBy.message));
      }
    }
    return FiscalTransmitBatchReport.fromEntries(rows, stoppedBy: stoppedBy);
  }
}
