// Contrato de dados da seção "No fisco" da OS — F2b (D-F4/D-F139/D-F142): o
// app é cliente DIRETO da nfse-api e lê o EFEITO e o PLANO do ERP. O que este
// teste fixa:
// (1) a VOZ (nfse-api): o estado e a tentativa VIGENTE vêm do servidor — o
//     app nunca deriva "autorizada"/"viva" de colunas (a vigente é a que o
//     servidor escolheu, não a última da lista);
// (2) o EFEITO (ERP): none/apply/decide/cancel + a decisão "manter" vigente;
//     valor desconhecido = neutro;
// (3) o PLANO (ERP): barreira fiscal TIPADA, bloqueios locais × fiscal, caixa,
//     e o predicado "só o fisco impede" que libera a saga;
// (4) os resultados das ações e o relatório do lote (contadores recontados).

import 'dart:io';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_fiscal_entity.dart';

void main() {
  group('voz do fisco (nfse-api)', () {
    test('transmissão: campos do fisco como texto (mysql2 devolve número ou string)', () {
      final tx = ServiceOrderFiscalTransmission.fromJson({
        'attempt': '2',
        'environment': 'P',
        'dpsId': 'DPS00000000000000000000000000000000000000001',
        'accessKey': '41260912345678000199900001000000000012345678901234',
        'nfseNumber': 123,
        'lastKind': 'A',
        'lastCode': 100,
        'lastMessage': 'Autorizado o uso da NFS-e',
      });
      expect(tx.attempt, 2);
      expect(tx.nfseNumber, '123');
      expect(tx.lastCode, '100');
      expect(tx.lastKind, FiscalTransmissionKind.authorized);
    });

    test('evento: código cru, origem; kind ausente vira vazio', () {
      final ev = ServiceOrderFiscalEvent.fromJson({
        'attempt': 1, 'event': 3, 'kind': 'C', 'authorityCode': 101101, 'source': 'Q',
      });
      expect(ev.event, 3);
      expect(ev.authorityCode, '101101');
      expect(ev.source, 'Q');
      expect(ServiceOrderFiscalEvent.fromJson({'attempt': 1, 'event': 1}).kind, '');
    });

    test('visão SEM state: desconhecido, sem ação (F2B-SOC-06 — ausência nunca é "nunca transmitida"); state none explícito: cabe transmitir', () {
      final v = ServiceOrderFiscalView.fromJson(const {});
      expect(v.state, NfseState.unknown);
      expect(v.canTransmitState, isFalse);
      expect(v.currentAttempt, isNull);
      expect(v.current, isNull);
      expect(v.localCancelPending, isFalse);
      expect(v.isSubstituted, isFalse);
      expect(v.xmlAvailable, isFalse);
      final none = ServiceOrderFiscalView.fromJson(const {'state': 'none'});
      expect([none.state, none.canTransmitState], [NfseState.none, isTrue]);
      expect(ServiceOrderFiscalView.fromJson(const {'state': 7}).state, NfseState.unknown, reason: 'tipo trocado = desconhecido');
    });

    test('a vigente é a que o SERVIDOR escolheu (currentAttempt), não a última da lista', () {
      final v = ServiceOrderFiscalView.fromJson({
        'state': 'authorized',
        'currentAttempt': 1,
        'transmissions': [
          {'attempt': 1, 'lastKind': 'A', 'accessKey': 'K1'},
          {'attempt': 2, 'lastKind': 'F'},
        ],
        'xmlAvailable': true,
      });
      expect(v.current!.attempt, 1);
      expect(v.current!.accessKey, 'K1');
      expect(v.canTransmitState, isFalse);
      expect(v.xmlAvailable, isTrue);
    });

    test('estados em que cabe transmitir = nunca transmitida ou fechou sem NFS-e', () {
      for (final s in [NfseState.none, NfseState.rejected, NfseState.failed]) {
        expect(ServiceOrderFiscalView(state: s).canTransmitState, isTrue, reason: s);
      }
      for (final s in [
        NfseState.inFlight, NfseState.processing, NfseState.authorized, NfseState.denied,
        NfseState.cancelled, NfseState.cancelInFlight, NfseState.unavailable, 'estado-novo',
      ]) {
        expect(ServiceOrderFiscalView(state: s).canTransmitState, isFalse, reason: s);
      }
    });

    test('substituição: chave da substituta; XML do evento indisponível = chave nula; bloco de tipo errado = sem substituição', () {
      final v = ServiceOrderFiscalView.fromJson({
        'state': 'cancelled',
        'localCancelPending': true,
        'substitution': {'substituteAccessKey': '41261012345678000199900001000000000099999999999999'},
      });
      expect(v.isSubstituted, isTrue);
      expect(v.substitution!.hasSubstituteKey, isTrue);
      expect(v.localCancelPending, isTrue);
      expect(ServiceOrderFiscalSubstitution.fromJson(const {'substituteAccessKey': ''}).hasSubstituteKey, isFalse);
      expect(ServiceOrderFiscalView.fromJson(const {'substitution': 'x'}).substitution, isNull);
    });
  });

  group('efeito na nota (ERP)', () {
    test('parse dos 4 efeitos; valor que o build não conhece = unknown (neutro)', () {
      expect(FiscalEffect.parse('none'), FiscalEffect.none);
      expect(FiscalEffect.parse('apply'), FiscalEffect.apply);
      expect(FiscalEffect.parse('decide'), FiscalEffect.decide);
      expect(FiscalEffect.parse('cancel'), FiscalEffect.cancel);
      expect(FiscalEffect.parse('novo'), FiscalEffect.unknown);
      expect(FiscalEffect.parse(null), FiscalEffect.unknown);
    });

    test('a decisão "manter" vigente vem inteira; ausente = null', () {
      final e = ServiceOrderFiscalEffect.fromJson({
        'effect': 'none',
        'invoiceCancelled': false,
        'cancelWaiver': {'accessKey': 'K1', 'reason': 'Substituta no portal', 'userId': '7', 'createdAt': '2026-10-10 15:42:00'},
      });
      expect(e.effect, FiscalEffect.none);
      expect(e.cancelWaiver!.userId, 7);
      expect(e.cancelWaiver!.reason, 'Substituta no portal');
      expect(ServiceOrderFiscalEffect.fromJson(const {'effect': 'decide'}).cancelWaiver, isNull);
      expect(ServiceOrderFiscalCancelWaiver.fromJson(const {}).accessKey, '');
    });
  });

  group('plano de cancelamento (ERP)', () {
    Map<String, dynamic> fiscalBlock(String kind, {String? reason}) => {
          'field': 'fiscal',
          'message': 'mensagem do servidor',
          'ref': 'fiscal',
          'barrier': {'kind': kind, 'reason': reason, 'attempt': 2},
        };

    test('cancelável sem bloqueios: sem barreira, sem bloqueio local', () {
      final p = ServiceOrderCancelPlan.fromJson({
        'orderId': '7374', 'invoiceNumber': 704, 'cancellable': true, 'fiscalRecord': false,
        'blocks': const [], 'effects': {'touchesCash': false},
      });
      expect(p.orderId, 7374);
      expect(p.invoiceNumber, '704');
      expect(p.cancellable, isTrue);
      expect(p.fiscalBarrier, isNull);
      expect(p.localBlocks, isEmpty);
      expect(p.cashierOpen, isNull, reason: 'não toca o caixa');
      expect(p.onlyAuthorityStands, isFalse);
    });

    test('barreira TIPADA: os 4 tipos + desconhecido; reconferir traz o motivo', () {
      for (final (raw, kind) in [
        ('authorized', FiscalBarrierKind.authorized),
        ('in-flight', FiscalBarrierKind.inFlight),
        ('cancel-in-flight', FiscalBarrierKind.cancelInFlight),
        ('reconfirm', FiscalBarrierKind.reconfirm),
        ('novo', FiscalBarrierKind.unknown),
      ]) {
        final p = ServiceOrderCancelPlan.fromJson({'orderId': 1, 'blocks': [fiscalBlock(raw, reason: 'sem-e2404')]});
        expect(p.fiscalBarrier!.kind, kind, reason: raw);
        expect(p.fiscalBarrier!.attempt, 2);
      }
      final r = ServiceOrderCancelPlan.fromJson({'orderId': 1, 'blocks': [fiscalBlock('reconfirm', reason: 'sem-e2404')]});
      expect(r.fiscalBarrier!.reason, 'sem-e2404');
    });

    test('só a NFS-e autorizada impede (caixa aberto ou não tocado) → a saga cabe', () {
      final p = ServiceOrderCancelPlan.fromJson({
        'orderId': 1, 'fiscalRecord': true,
        'blocks': [fiscalBlock('authorized')],
        'effects': {'touchesCash': true, 'cashierOpen': true},
      });
      expect(p.onlyAuthorityStands, isTrue);
      expect(p.fiscalRecord, isTrue);
      expect(p.touchesCash, isTrue);
    });

    test('autorizada + bloqueio LOCAL (título baixado) → a saga NÃO cabe (o local recusaria depois do fisco)', () {
      final p = ServiceOrderCancelPlan.fromJson({
        'orderId': 1,
        'blocks': [
          fiscalBlock('authorized'),
          {'field': 'title', 'message': 'Título 7650/1 tem baixa de 80.00 — estorne a baixa antes', 'ref': '7650/1'},
        ],
      });
      expect(p.localBlocks.single.field, 'title');
      expect(p.onlyAuthorityStands, isFalse);
    });

    test('autorizada + caixa FECHADO (toca o caixa) → a saga NÃO cabe', () {
      final p = ServiceOrderCancelPlan.fromJson({
        'orderId': 1,
        'blocks': [fiscalBlock('authorized')],
        'effects': {'touchesCash': true, 'cashierOpen': false},
      });
      expect(p.cashierOpen, isFalse);
      expect(p.onlyAuthorityStands, isFalse);
    });

    test('barreira que não é "autorizada" nunca libera a saga', () {
      for (final k in ['in-flight', 'cancel-in-flight', 'reconfirm', 'novo']) {
        final p = ServiceOrderCancelPlan.fromJson({'orderId': 1, 'blocks': [fiscalBlock(k)]});
        expect(p.onlyAuthorityStands, isFalse, reason: k);
      }
    });

    test('cashierOpen de tipo errado vira null (não inventa caixa aberto nem fechado)', () {
      final p = ServiceOrderCancelPlan.fromJson({'orderId': 1, 'effects': {'cashierOpen': 'S'}});
      expect(p.cashierOpen, isNull);
    });
  });

  group('desfecho desconhecido no fisco (D-F139 — nunca "não aconteceu")', () {
    test('rede, resposta ambígua e fisco fora = desconhecido; recusa e regra não', () {
      expect(isUnknownAuthorityOutcome(const NetworkFailure()), isTrue);
      expect(isUnknownAuthorityOutcome(
          const Failure(message: 'x', statusCode: 502, code: FiscalCodes.authorityUnknown)), isTrue);
      expect(isUnknownAuthorityOutcome(
          const Failure(message: 'x', statusCode: 503, code: FiscalCodes.authorityUnavailable)), isTrue);
      expect(isUnknownAuthorityOutcome(
          const Failure(message: 'x', statusCode: 422, code: FiscalCodes.dpsRejected)), isFalse);
      // D-F163 (= Q-F171 (a)): a contenção num ATO pode vir DEPOIS do fisco — desconhecido
      expect(isUnknownAuthorityOutcome(
          const Failure(message: 'x', statusCode: 409, code: FiscalCodes.resourceBusy)), isTrue);
      expect(isUnknownAuthorityOutcome(
          const Failure(message: 'x', statusCode: 503, code: FiscalCodes.voiceUnavailable)), isFalse,
          reason: 'a VOZ indisponível no ERP é leitura, não ato no fisco');
    });
  });

  group('resultados das ações', () {
    test('transmit (201 só com A): chave e número', () {
      final r = ServiceOrderTransmitResult.fromJson({'invoiceId': '6190', 'attempt': 1, 'accessKey': 'KEY', 'nfseNumber': 704});
      expect(r.invoiceId, 6190);
      expect(r.accessKey, 'KEY');
      expect(r.nfseNumber, '704');
    });

    test('refresh: changed false por default', () {
      expect(ServiceOrderFiscalRefreshResult.fromJson(const {}).changed, isFalse);
    });

    test('reconfirm: found/verdict', () {
      final r = ServiceOrderFiscalReconfirmResult.fromJson({'needed': true, 'found': false, 'verdict': 'provada'});
      expect(r.needed, isTrue);
      expect(r.found, isFalse);
      expect(r.verdict, 'provada');
    });

    test('cancel no fisco: atAuthority default true; warnings vazios filtrados', () {
      final c = ServiceOrderFiscalCancelResult.fromJson({
        'invoiceId': 1, 'warnings': ['Evento arquivado com atraso', ''],
      });
      expect(c.atAuthority, isTrue);
      expect(c.warnings, ['Evento arquivado com atraso']);
      expect(ServiceOrderFiscalCancelResult.fromJson({'invoiceId': 1, 'atAuthority': false}).atAuthority, isFalse);
    });

    test('manter a nota: alreadyWaived default false', () {
      final r = ServiceOrderCancelWaiverResult.fromJson({'orderId': '7223', 'accessKey': 'K1', 'alreadyWaived': true});
      expect(r.orderId, 7223);
      expect(r.alreadyWaived, isTrue);
      expect(ServiceOrderCancelWaiverResult.fromJson({'orderId': 1}).alreadyWaived, isFalse);
    });

    test('pendente: invoiceId É o orderId (1 pedido = 1 nota com o mesmo id)', () {
      final p = ServiceOrderFiscalPending.fromJson({'invoiceId': '77', 'number': 12, 'dtEmission': '2026-09-01'});
      expect(p.orderId, 77);
      expect(p.number, '12');
    });
  });

  group('relatório do lote', () {
    test('contadores recontados das linhas; aborted marca o código local', () {
      final r = FiscalTransmitBatchReport.fromEntries(const [
        FiscalTransmitBatchRow(orderId: 1, ok: true),
        FiscalTransmitBatchRow(orderId: 2, ok: false, code: FiscalCodes.dpsRejected, message: 'E0123'),
        FiscalTransmitBatchRow.aborted(orderId: 3, message: 'Sem privilégio'),
      ], stoppedBy: const Failure(message: 'Sem privilégio', statusCode: 403));
      expect(r.requested, 3);
      expect(r.transmitted, 1);
      // D-F171 (= Q-F179 (a)): a não tentada tem contador próprio — não é "recusada"
      expect([r.refused, r.notTried], [1, 1]);
      expect(r.refusedRows.map((e) => e.orderId), [2]);
      expect(r.notTriedRows.map((e) => e.orderId), [3]);
      expect(r.rows.last.code, FiscalTransmitBatchRow.abortedCode);
      expect(r.stoppedBy!.statusCode, 403);
    });

    test('D-F168 (= Q-F176 (a)): o desfecho DESCONHECIDO tem contador e linhas próprios — nunca "recusada"', () {
      final r = FiscalTransmitBatchReport.fromEntries(const [
        FiscalTransmitBatchRow(orderId: 1, ok: true),
        FiscalTransmitBatchRow(orderId: 2, ok: false, code: FiscalCodes.resourceBusy, message: 'Nota em uso', unknown: true),
        FiscalTransmitBatchRow(orderId: 3, ok: false, code: FiscalCodes.dpsRejected, message: 'E0123'),
      ]);
      expect([r.transmitted, r.refused, r.uncertain], [1, 1, 1]);
      expect([r.refusedRows.single.orderId, r.uncertainRows.single.orderId], [3, 2]);
      for (final lang in ['pt', 'en']) {
        final json = File('assets/translations/$lang.json').readAsStringSync();
        expect([lang, json.contains('"fiscalBatchSummaryUncertainPart"'), json.contains('"fiscalBatchSummaryNotTriedPart"'),
          json.contains('"fiscalBatchUncertainRow"'), json.contains('"fiscalBatchSummaryUncertain"')], [lang, true, true, true, false]);
      }
    });

    test('R11-SOC-04 (cerca): TODO código de `ClientFailureCodes` está em `ClientFailureCodes.all` — a lista que a D-F180 usa para tirar o "ref" da falha montada pelo app', () {
      final src = File('../../packages/core/lib/src/shared/http/api_client.dart').readAsStringSync();
      final body = src.substring(src.indexOf('abstract final class ClientFailureCodes'), src.indexOf('static const all'));
      final declared = RegExp(r"static const \w+ = '([A-Z_]+)';").allMatches(body).map((m) => m.group(1)).toSet();
      expect(declared, isNotEmpty);
      expect(ClientFailureCodes.all, declared, reason: 'código novo do cliente entra na lista');
    });

    test('D-F176 (= Q-F184 (b)) + D-F181: sem código, o status HTTP ("HTTP 503"); a rede caída sem complemento (a página diz a frase neutra)', () {
      expect(const FiscalTransmitBatchRow(orderId: 1, ok: false, unknown: true, httpStatus: 503).uncertainDetail, ' (HTTP 503)');
      expect(const FiscalTransmitBatchRow(orderId: 1, ok: false, unknown: true, httpStatus: 500, supportRef: 'x1').uncertainDetail, ' (HTTP 500 · ref x1)');
      expect(const FiscalTransmitBatchRow(orderId: 1, ok: false, code: 'INTERNAL', unknown: true, httpStatus: 500).uncertainDetail, ' (INTERNAL)');
      expect(const FiscalTransmitBatchRow(orderId: 1, ok: false, unknown: true, network: true, supportRef: 'ClientException').uncertainDetail, '');
      for (final lang in ['pt', 'en']) {
        expect(File('assets/translations/$lang.json').readAsStringSync().contains('"fiscalBatchNoResponse"'), isTrue);
      }
    });

    test('R8-SOC-02: o complemento da incerta só com conteúdo — sem código nem ref (gateway sem envelope) nada de "()"', () {
      expect(const FiscalTransmitBatchRow(orderId: 1, ok: false, unknown: true).uncertainDetail, '');
      expect(const FiscalTransmitBatchRow(orderId: 1, ok: false, code: 'INTERNAL', unknown: true).uncertainDetail, ' (INTERNAL)');
      expect(const FiscalTransmitBatchRow(orderId: 1, ok: false, code: 'INTERNAL', unknown: true, supportRef: 'ab12').uncertainDetail,
          ' (INTERNAL · ref ab12)');
      for (final lang in ['pt', 'en']) {
        final json = File('assets/translations/$lang.json').readAsStringSync();
        final row = RegExp('"fiscalBatchUncertainRow": "([^"]*)"').firstMatch(json)!.group(1)!;
        expect([lang, '{}'.allMatches(row).length, row.contains('()')], [lang, 1, false]);
      }
    });

    test('R7-SOC-02: a não tentada se reconhece (notTried); a incerta guarda o ref; as chaves novas existem em pt e en', () {
      const aborted = FiscalTransmitBatchRow.aborted(orderId: 9, message: 'Registro em uso — tente novamente');
      const uncertain = FiscalTransmitBatchRow(orderId: 8, ok: false, code: FiscalCodes.resourceBusy, unknown: true, supportRef: 'R7X');
      expect([aborted.notTried, uncertain.notTried, uncertain.supportRef], [true, false, 'R7X']);
      for (final lang in ['pt', 'en']) {
        final json = File('assets/translations/$lang.json').readAsStringSync();
        expect([lang, json.contains('"fiscalBatchNotTriedRow"'), json.contains('"fiscalBatchStoppedUncertain"')], [lang, true, true]);
      }
    });
  });
}
