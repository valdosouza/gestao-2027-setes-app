// Contrato de dados da Onda 3 (NFS-e pelo ADN) no módulo service_orders:
// parse da visão fiscal (/api/billing/fiscal/:orderId → transmissions/events),
// vigência da transmissão, NFS-e autorizada, cancelamento em voo, pendências
// (voz com efeito recusado — D-I10), a substituição no fisco + decisão de
// manter a nota (D-F67) e os resultados de transmitir/consultar/cancelar/lote.

import 'package:flutter_test/flutter_test.dart';
import 'package:setes_web/app/modules/service_orders/domain/entity/service_order_fiscal_entity.dart';

void main() {
  group('ServiceOrderFiscalTransmission', () {
    test('fromJson lê a transmissão com os campos write-once do fisco', () {
      final tx = ServiceOrderFiscalTransmission.fromJson({
        'attempt': '2', // mysql2 pode devolver como string
        'environment': 'P',
        'dpsId': 'DPS00000000000000000000000000000000000000001',
        'accessKey': '41260912345678000199900001000000000012345678901234',
        'nfseNumber': 123,
        'dhProc': '2026-09-21T10:15:00-03:00',
        'createdAt': '2026-09-21 10:14:00',
        'lastQueriedAt': '2026-09-21 10:20:00',
        'lastKind': 'A',
        'lastCode': 100,
        'lastMessage': 'Autorizado o uso da NFS-e',
        'lastDh': '2026-09-21T10:15:00-03:00',
      });
      expect(tx.attempt, 2);
      expect(tx.environment, 'P');
      expect(tx.nfseNumber, '123');
      expect(tx.lastCode, '100');
      expect(tx.isAuthorized, isTrue);
      expect(tx.isLive, isTrue);
      expect(tx.inFlight, isFalse);
      expect(tx.cancelInFlight, isFalse);
    });

    test('defaults: sem ambiente = PRODUÇÃO (conservador — gate 2026-09-30); sem DPS nem evento = em voo',
        () {
      final tx = ServiceOrderFiscalTransmission.fromJson({'attempt': 1});
      expect(tx.environment, 'P');
      expect(tx.inFlight, isTrue);
      expect(tx.isLive, isTrue, reason: 'envio em andamento ainda é vigente');
      expect(tx.isAuthorized, isFalse);
    });

    test('isLive: R/C/F encerram a transmissão; S/A/K e null não', () {
      bool live(String? kind) =>
          ServiceOrderFiscalTransmission(attempt: 1, dpsId: 'x', lastKind: kind)
              .isLive;
      for (final k in [null, 'S', 'A', 'K']) {
        expect(live(k), isTrue, reason: 'kind $k deveria ser vigente');
      }
      for (final k in ['R', 'C', 'F']) {
        expect(live(k), isFalse, reason: 'kind $k deveria ser final');
      }
      expect(FiscalTransmissionKind.finals, {'R', 'C', 'F'});
    });
  });

  group('ServiceOrderFiscalEvent', () {
    test('fromJson lê a voz do fisco com código cru, origem e efeito na nota',
        () {
      final ev = ServiceOrderFiscalEvent.fromJson({
        'attempt': 1,
        'event': 3,
        'kind': 'C',
        'authorityCode': 'E0000',
        'message': 'Cancelamento homologado',
        'dh': '2026-09-22T09:00:00-03:00',
        'source': 'P',
        'invoiceEvent': 2,
        'createdAt': '2026-09-22 09:00:01',
      });
      expect(ev.event, 3);
      expect(ev.kind, 'C');
      expect(ev.authorityCode, 'E0000');
      expect(ev.source, 'P');
      expect(ev.invoiceEvent, 2);
    });

    test('sem invoiceEvent e sem código: campos nulos, kind vazio não quebra',
        () {
      final ev = ServiceOrderFiscalEvent.fromJson({'attempt': 1, 'event': 1});
      expect(ev.kind, '');
      expect(ev.invoiceEvent, isNull);
      expect(ev.authorityCode, isNull);
    });
  });

  group('ServiceOrderFiscalView', () {
    ServiceOrderFiscalView view(List<Map<String, dynamic>> transmissions,
            {int pending = 0}) =>
        ServiceOrderFiscalView.fromJson({
          'transmissions': transmissions,
          'events': const [],
          'pendingEffects': pending,
          'xmlAvailable': true,
          'danfseAvailable': false,
        });

    test('fromJson: nunca transmitida = sem vigente, sem autorização', () {
      final v = ServiceOrderFiscalView.fromJson(const {});
      expect(v.lastTransmission, isNull);
      expect(v.hasLiveTransmission, isFalse);
      expect(v.isAuthorized, isFalse);
      expect(v.blocksLocalCancel, isFalse);
      expect(v.hasPendingEffects, isFalse);
      expect(v.xmlAvailable, isFalse);
    });

    test('lastTransmission é a ÚLTIMA da lista (reapresentar = attempt + 1)',
        () {
      final v = view([
        {'attempt': 1, 'dpsId': 'a', 'lastKind': 'R'},
        {'attempt': 2, 'dpsId': 'b', 'lastKind': 'A', 'accessKey': 'K2', 'environment': 'P'},
      ]);
      expect(v.lastTransmission!.attempt, 2);
      expect(v.hasLiveTransmission, isTrue);
      expect(v.isAuthorized, isTrue);
      expect(v.blocksLocalCancel, isTrue,
          reason: 'autorizada em PRODUÇÃO esconde o "Cancelar nota" local');
      expect(v.xmlAvailable, isTrue);
      expect(v.danfseAvailable, isFalse);
    });

    test('Q-CA5b: autorizada em HOMOLOGAÇÃO libera o cancelamento local; K continua bloqueando', () {
      final h = view([
        {'attempt': 1, 'dpsId': 'a', 'lastKind': 'A', 'accessKey': 'K1', 'environment': 'H'},
      ]);
      expect(h.isAuthorized, isTrue);
      expect(h.blocksLocalCancel, isFalse);
      final k = view([
        {'attempt': 1, 'dpsId': 'a', 'lastKind': 'K', 'accessKey': 'K1', 'environment': 'H'},
      ]);
      expect(k.blocksLocalCancel, isTrue);
    });

    test('rejeitada encerra: cabe nova transmissão e o cancel local volta',
        () {
      final v = view([
        {'attempt': 1, 'dpsId': 'a', 'lastKind': 'R', 'lastCode': 'E0123'},
      ]);
      expect(v.hasLiveTransmission, isFalse);
      expect(v.isAuthorized, isFalse);
      expect(v.blocksLocalCancel, isFalse);
    });

    test('cancelamento em voo (K) bloqueia o cancel local sem ser autorizada',
        () {
      final v = view([
        {'attempt': 1, 'dpsId': 'a', 'lastKind': 'K'},
      ]);
      expect(v.cancelInFlight, isTrue);
      expect(v.isAuthorized, isFalse);
      expect(v.hasLiveTransmission, isTrue);
      expect(v.blocksLocalCancel, isTrue);
    });

    test('pendingEffects > 0 = pendência visível (D-I10)', () {
      final v = view([
        {'attempt': 1, 'dpsId': 'a', 'lastKind': 'A'},
      ], pending: 1);
      expect(v.hasPendingEffects, isTrue);
      expect(v.pendingEffects, 1);
    });
  });

  // D-F67 (Valdo 2026-10-10): NFS-e cancelada POR SUBSTITUIÇÃO no fisco
  // (e105102, fora do produto) — a nota fica viva até o humano decidir:
  // cancelar a nota ou MANTÊ-LA (POST /api/billing/cancel-waiver).
  group('D-F67 — substituição e decisão de manter', () {
    const substitute = '41261012345678000199900001000000000099999999999999';

    test('sem os blocos novos (API antiga ou nota comum): nada de substituição',
        () {
      final v = ServiceOrderFiscalView.fromJson({
        'transmissions': [
          {'attempt': 1, 'dpsId': 'a', 'lastKind': 'A', 'accessKey': 'K1'},
        ],
        'pendingEffects': 0,
      });
      expect(v.substitution, isNull);
      expect(v.cancelWaiver, isNull);
      expect(v.isSubstituted, isFalse);
      expect(v.substitutionDecided, isFalse);
      expect(v.canWaiveCancel, isFalse);
    });

    test('blocos null explícitos ou de tipo errado são tolerados (viram null)',
        () {
      final nulls = ServiceOrderFiscalView.fromJson(
          {'substitution': null, 'cancelWaiver': null});
      expect(nulls.substitution, isNull);
      expect(nulls.cancelWaiver, isNull);

      final wrong = ServiceOrderFiscalView.fromJson(
          {'substitution': 'x', 'cancelWaiver': 1});
      expect(wrong.substitution, isNull);
      expect(wrong.cancelWaiver, isNull);
    });

    test('substituída SEM decisão: chave da substituta + "Manter a nota" cabe',
        () {
      final v = ServiceOrderFiscalView.fromJson({
        'transmissions': [
          {'attempt': 1, 'dpsId': 'a', 'lastKind': 'C', 'accessKey': 'K1'},
        ],
        'pendingEffects': 1,
        'substitution': {'substituteAccessKey': substitute, 'waived': false},
        'cancelWaiver': null,
      });
      expect(v.isSubstituted, isTrue);
      expect(v.substitution!.substituteAccessKey, substitute);
      expect(v.substitution!.hasSubstituteKey, isTrue);
      expect(v.substitution!.waived, isFalse);
      expect(v.substitutionDecided, isFalse);
      expect(v.canWaiveCancel, isTrue);
      expect(v.hasPendingEffects, isTrue);
      // a voz é C (final): o "Cancelar nota" local segue disponível
      expect(v.blocksLocalCancel, isFalse);
    });

    test('D-F80: substituição em HOMOLOGAÇÃO não se mantém (cancela-se a nota); toda voz C esconde o Transmitir (L4)',
        () {
      final h = ServiceOrderFiscalView.fromJson({
        'transmissions': [
          {'attempt': 1, 'dpsId': 'a', 'lastKind': 'C', 'accessKey': 'K1', 'environment': 'H'},
        ],
        'pendingEffects': 1,
        'substitution': {'substituteAccessKey': null, 'waived': false},
      });
      expect(h.isSubstituted, isTrue);
      expect(h.canWaiveCancel, isFalse);
      expect(h.hasCancelVoice, isTrue);
      final exOfficio = ServiceOrderFiscalView.fromJson({
        'transmissions': [
          {'attempt': 1, 'dpsId': 'a', 'lastKind': 'C', 'lastCode': '305101', 'accessKey': 'K1'},
        ],
        'pendingEffects': 1,
      });
      expect(exOfficio.isSubstituted, isFalse);
      expect(exOfficio.canWaiveCancel, isFalse);
      expect(exOfficio.hasCancelVoice, isTrue);
      final authorized = ServiceOrderFiscalView.fromJson({
        'transmissions': [
          {'attempt': 1, 'dpsId': 'a', 'lastKind': 'A', 'accessKey': 'K1'},
        ],
      });
      expect(authorized.hasCancelVoice, isFalse);
    });

    test('XML do evento indisponível: chave null (a tela mostra "indisponível")',
        () {
      final v = ServiceOrderFiscalView.fromJson({
        'substitution': {'substituteAccessKey': null, 'waived': false},
      });
      expect(v.substitution!.substituteAccessKey, isNull);
      expect(v.substitution!.hasSubstituteKey, isFalse);
      expect(v.canWaiveCancel, isTrue);

      final empty = ServiceOrderFiscalSubstitution.fromJson(
          {'substituteAccessKey': ''});
      expect(empty.hasSubstituteKey, isFalse);
      expect(empty.waived, isFalse, reason: 'sem o campo = não mantida');
    });

    test('mantida: cancelWaiver lido por inteiro e o botão some', () {
      final v = ServiceOrderFiscalView.fromJson({
        'pendingEffects': 0, // a substituição mantida deixa de contar
        'substitution': {'substituteAccessKey': substitute, 'waived': true},
        'cancelWaiver': {
          'accessKey': 'K1',
          'reason': 'Substituta emitida no portal pelo contador',
          'userId': '7', // mysql2 pode devolver como string
          'createdAt': '2026-10-10 15:42:00',
        },
      });
      final w = v.cancelWaiver!;
      expect(w.accessKey, 'K1');
      expect(w.reason, 'Substituta emitida no portal pelo contador');
      expect(w.userId, 7);
      expect(w.createdAt, '2026-10-10 15:42:00');
      expect(v.substitutionDecided, isTrue);
      expect(v.canWaiveCancel, isFalse);
      expect(v.hasPendingEffects, isFalse);
    });

    test('qualquer das duas leituras da API basta para dar a decisão por tomada',
        () {
      final soWaived = ServiceOrderFiscalView.fromJson({
        'substitution': {'substituteAccessKey': substitute, 'waived': true},
      });
      expect(soWaived.canWaiveCancel, isFalse);

      final soRegistro = ServiceOrderFiscalView.fromJson({
        'substitution': {'substituteAccessKey': substitute, 'waived': false},
        'cancelWaiver': {'accessKey': 'K1', 'reason': 'ok'},
      });
      expect(soRegistro.canWaiveCancel, isFalse);
    });

    test('cancelWaiver sem campos opcionais não quebra', () {
      final w = ServiceOrderFiscalCancelWaiver.fromJson(const {});
      expect(w.accessKey, '');
      expect(w.reason, '');
      expect(w.userId, isNull);
      expect(w.createdAt, isNull);
    });

    test('resultado do POST cancel-waiver: alreadyWaived default false', () {
      final r = ServiceOrderCancelWaiverResult.fromJson({
        'orderId': '7223',
        'accessKey': 'K1',
        'createdAt': '2026-10-10 15:42:00',
        'alreadyWaived': true,
      });
      expect(r.orderId, 7223);
      expect(r.accessKey, 'K1');
      expect(r.alreadyWaived, isTrue);

      final novo = ServiceOrderCancelWaiverResult.fromJson({'orderId': 1});
      expect(novo.alreadyWaived, isFalse);
    });

    test('igualdade: blocos novos entram no Equatable da visão', () {
      Map<String, dynamic> json(bool waived) => {
            'substitution': {'substituteAccessKey': substitute, 'waived': waived},
          };
      expect(ServiceOrderFiscalView.fromJson(json(false)),
          ServiceOrderFiscalView.fromJson(json(false)));
      expect(ServiceOrderFiscalView.fromJson(json(false)),
          isNot(ServiceOrderFiscalView.fromJson(json(true))));
    });
  });

  group('resultados das ações', () {
    test('transmit: kind A = autorizada com chave', () {
      final r = ServiceOrderTransmitResult.fromJson({
        'invoiceId': 6190,
        'attempt': 1,
        'dpsId': 'DPS1',
        'accessKey': 'KEY',
        'kind': 'A',
      });
      expect(r.invoiceId, 6190);
      expect(r.authorized, isTrue);
      expect(r.accessKey, 'KEY');
    });

    test('refresh: changed false por default', () {
      final r = ServiceOrderFiscalRefreshResult.fromJson(const {});
      expect(r.changed, isFalse);
      expect(r.authorized, isFalse);
    });

    test('cancel: C = cancelada, K = em voo; warnings vazios filtrados', () {
      final c = ServiceOrderFiscalCancelResult.fromJson({
        'invoiceId': 1,
        'kind': 'C',
        'warnings': ['Boleto vinculado cancelado junto', ''],
      });
      expect(c.cancelled, isTrue);
      expect(c.inFlight, isFalse);
      expect(c.warnings, ['Boleto vinculado cancelado junto']);

      final k = ServiceOrderFiscalCancelResult.fromJson({'invoiceId': 1, 'kind': 'K'});
      expect(k.inFlight, isTrue);
      expect(k.warnings, isEmpty);
    });

    test('pending: invoiceId É o orderId (1 pedido = 1 nota com o mesmo id)',
        () {
      final p = ServiceOrderFiscalPending.fromJson(
          {'invoiceId': '77', 'number': 12, 'dtEmission': '2026-09-01'});
      expect(p.invoiceId, 77);
      expect(p.orderId, 77);
      expect(p.number, '12');
    });
  });

  group('FiscalTransmitBatchReport', () {
    test('fromJson reconta os contadores das linhas (a fonte é uma)', () {
      final r = FiscalTransmitBatchReport.fromJson({
        'transmitted': 99, // ignorado de propósito — as linhas mandam
        'refused': 0,
        'rows': [
          {'orderId': 1, 'ok': true, 'kind': 'A'},
          {'orderId': 2, 'ok': false, 'code': 'FISCAL_DPS_REJECTED', 'message': 'E0123'},
          {'orderId': 3}, // sem ok explícito = recusada
        ],
      });
      expect(r.requested, 3);
      expect(r.transmitted, 1);
      expect(r.refused, 2);
      expect(r.refusedRows.map((e) => e.orderId), [2, 3]);
      expect(r.rows[1].code, 'FISCAL_DPS_REJECTED');
    });

    test('merge agrega os blocos na ordem e aborted marca o código local', () {
      final merged = FiscalTransmitBatchReport.merge([
        FiscalTransmitBatchReport.fromEntries(const [
          FiscalTransmitBatchRow(orderId: 1, ok: true),
        ]),
        FiscalTransmitBatchReport.fromEntries(const [
          FiscalTransmitBatchRow.aborted(orderId: 2, message: 'rede'),
        ]),
      ]);
      expect(merged.rows.map((e) => e.orderId), [1, 2]);
      expect(merged.transmitted, 1);
      expect(merged.refused, 1);
      expect(merged.rows.last.code, FiscalTransmitBatchRow.abortedCode);
      expect(merged.rows.last.message, 'rede');
    });
  });
}
