// Contrato de dados da Onda 3 (NFS-e pelo ADN) no módulo service_orders:
// parse da visão fiscal (/api/billing/fiscal/:orderId → transmissions/events),
// vigência da transmissão, NFS-e autorizada, cancelamento em voo, pendências
// (voz com efeito recusado — D-I10) e os resultados de transmitir/consultar/
// cancelar/lote.

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

    test('defaults: sem ambiente = produção restrita; sem DPS nem evento = em voo',
        () {
      final tx = ServiceOrderFiscalTransmission.fromJson({'attempt': 1});
      expect(tx.environment, 'H');
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
        {'attempt': 2, 'dpsId': 'b', 'lastKind': 'A', 'accessKey': 'K2'},
      ]);
      expect(v.lastTransmission!.attempt, 2);
      expect(v.hasLiveTransmission, isTrue);
      expect(v.isAuthorized, isTrue);
      expect(v.blocksLocalCancel, isTrue,
          reason: 'autorizada esconde o "Cancelar nota" local');
      expect(v.xmlAvailable, isTrue);
      expect(v.danfseAvailable, isFalse);
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
