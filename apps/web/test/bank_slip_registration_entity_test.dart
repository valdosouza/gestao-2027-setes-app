// Contrato de dados da Onda 2 (Banco Inter) no módulo bank_slips: parse das
// apresentações ao banco e da voz do banco (/api/bank-slips/:id →
// registrations/registrationEvents), vigência da apresentação, pendências
// (efeito recusado — D-I10) e resultados de registrar/atualizar/consulta ativa.

import 'package:flutter_test/flutter_test.dart';
import 'package:setes_web/app/modules/bank_slips/domain/entity/bank_slip_entity.dart';

void main() {
  group('BankSlipRegistration', () {
    test('fromJson lê a apresentação com os campos write-once do banco', () {
      final reg = BankSlipRegistration.fromJson({
        'attempt': '2', // mysql2 pode devolver como string
        'environment': 'P',
        'requestCode': 'abc-123',
        'bankOurNumber': '00000000123',
        'digitableLine': '07790.00116 00000.000000 00000.000000 1 00000000010000',
        'barcode': '07791000000000100000000000000000000000000000',
        'pixCopyPaste': '00020126...',
        'pixTxid': 'TX1',
        'createdAt': '2026-09-19 10:00:00',
        'lastKind': 'G',
        'lastBankStatus': 'A_RECEBER',
        'lastDtBankStatus': '2026-09-19',
      });
      expect(reg.attempt, 2);
      expect(reg.environment, 'P');
      expect(reg.requestCode, 'abc-123');
      expect(reg.digitableLine, contains('07790'));
      expect(reg.lastKind, BankSlipRegistrationKind.registered);
      expect(reg.isLive, isTrue);
      expect(reg.inFlight, isFalse);
    });

    test('defaults: sem ambiente = sandbox; sem código nem evento = em voo', () {
      final reg = BankSlipRegistration.fromJson({'attempt': 1});
      expect(reg.environment, 'S');
      expect(reg.inFlight, isTrue);
      expect(reg.isLive, isTrue, reason: 'envio em andamento ainda é vigente');
    });

    test('isLive: kinds finais encerram a apresentação, os demais não', () {
      bool live(String? kind) =>
          BankSlipRegistration(attempt: 1, requestCode: 'x', lastKind: kind).isLive;

      for (final k in ['S', 'G', 'M', 'A', 'P', 'K']) {
        expect(live(k), isTrue, reason: 'kind $k deveria ser vigente');
      }
      for (final k in ['R', 'C', 'V', 'F', 'E']) {
        expect(live(k), isFalse, reason: 'kind $k deveria ser final');
      }
      // E (efeito reaplicado — D-I25) encerra como a voz que reaplica.
      expect(BankSlipRegistrationKind.finals, {'R', 'C', 'V', 'F', 'E'});
    });
  });

  group('BankSlipRegistrationEvent', () {
    test('fromJson lê a fala do banco com valor e meio de pagamento', () {
      final ev = BankSlipRegistrationEvent.fromJson({
        'attempt': 1,
        'event': 3,
        'kind': 'R',
        'bankStatus': 'RECEBIDO',
        'dtBankStatus': '2026-09-20',
        'source': 'W',
        'paidValue': '150.50',
        'paidBy': 'X',
        'slipEvent': 2,
        'message': null,
        'createdAt': '2026-09-20 08:00:00',
      });
      expect(ev.event, 3);
      expect(ev.kind, BankSlipRegistrationKind.received);
      expect(ev.paidValue, 150.5);
      expect(ev.paidBy, 'X');
      expect(ev.source, 'W');
      expect(ev.slipEvent, 2);
      expect(ev.effectRefused, isFalse, reason: 'R com slipEvent = liquidou aqui');
    });

    test('RECEBIDO sem slipEvent = efeito recusado (pendência D-I10)', () {
      final refused = BankSlipRegistrationEvent.fromJson({
        'attempt': 1, 'event': 4, 'kind': 'R', 'slipEvent': null,
        'message': 'Efeito recusado: BANK_SLIP_NOT_OPEN',
      });
      expect(refused.effectRefused, isTrue);

      // Mesma regra da API (PENDING_EFFECT_WHERE — D-I28): C e V sem
      // slipEvent também são pendência (a regra pode recusar o C — ex.:
      // boleto já liquidado aqui); S/G/K/E nunca.
      final cancelled = BankSlipRegistrationEvent.fromJson(
          {'attempt': 1, 'event': 5, 'kind': 'C', 'slipEvent': null});
      expect(cancelled.effectRefused, isTrue);
      for (final k in ['S', 'G', 'M', 'A', 'P', 'K', 'F', 'E']) {
        final ev = BankSlipRegistrationEvent.fromJson(
            {'attempt': 1, 'event': 6, 'kind': k, 'slipEvent': null});
        expect(ev.effectRefused, isFalse, reason: 'kind $k não tem efeito');
      }
    });

    test('D-I25: reaplicado → o original recebe slipEvent e sai da pendência; E carrega o efeito', () {
      final original = BankSlipRegistrationEvent.fromJson(
          {'attempt': 1, 'event': 4, 'kind': 'R', 'slipEvent': 9, 'message': 'Efeito reaplicado (evento 5)'});
      expect(original.effectRefused, isFalse);
      final reapplied = BankSlipRegistrationEvent.fromJson(
          {'attempt': 1, 'event': 5, 'kind': 'E', 'source': 'P', 'slipEvent': 9});
      expect(reapplied.kind, BankSlipRegistrationKind.reapplied);
      expect(reapplied.effectRefused, isFalse);
      final r = BankSlipReapplyResult.fromJson({'attempt': 1, 'event': 4, 'reapplyEvent': 5, 'slipEvent': '9'});
      expect(r.slipEvent, 9);
      expect(r.reapplyEvent, 5);
    });

    test('D-I28: a linha da lista carrega pendingBankEffects (ausente = 0)', () {
      final row = BankSlipListRow.fromJson({'id': 1, 'pendingBankEffects': '2'});
      expect(row.pendingBankEffects, 2);
      expect(row.hasPendingBankEffects, isTrue);
      expect(BankSlipListRow.fromJson({'id': 2}).hasPendingBankEffects, isFalse);
    });
  });

  group('BankSlipFull (Onda 2)', () {
    Map<String, dynamic> base() => {
          'id': 7, 'state': 'open', 'value': 100,
          'registrations': <Map<String, dynamic>>[],
          'registrationEvents': <Map<String, dynamic>>[],
        };

    test('nunca registrado: sem apresentação, sem vigência, sem pendência', () {
      final slip = BankSlipFull.fromJson(base());
      expect(slip.registrations, isEmpty);
      expect(slip.lastRegistration, isNull);
      expect(slip.hasLiveRegistration, isFalse);
      expect(slip.refusedEffects, isEmpty);
    });

    test('detalhe legado sem as chaves da Onda 2 continua parseando', () {
      final slip = BankSlipFull.fromJson({'id': 1, 'state': 'open'});
      expect(slip.registrations, isEmpty);
      expect(slip.registrationEvents, isEmpty);
      expect(slip.hasLiveRegistration, isFalse);
    });

    test('lastRegistration é a ÚLTIMA da lista (tentativa mais recente)', () {
      final slip = BankSlipFull.fromJson(base()
        ..['registrations'] = [
          {'attempt': 1, 'requestCode': 'a', 'lastKind': 'F'},
          {'attempt': 2, 'requestCode': 'b', 'lastKind': 'G'},
        ]);
      expect(slip.lastRegistration!.attempt, 2);
      expect(slip.hasLiveRegistration, isTrue, reason: 'G é vigente → bloqueia novo registro');
    });

    test('tentativa falhada libera novo registro', () {
      final slip = BankSlipFull.fromJson(base()
        ..['registrations'] = [
          {'attempt': 1, 'requestCode': 'a', 'lastKind': 'F'},
        ]);
      expect(slip.hasLiveRegistration, isFalse);
    });

    test('refusedEffects filtra só os R sem efeito, preservando a ordem', () {
      final slip = BankSlipFull.fromJson(base()
        ..['registrations'] = [
          {'attempt': 1, 'requestCode': 'a', 'lastKind': 'R'},
        ]
        ..['registrationEvents'] = [
          {'attempt': 1, 'event': 1, 'kind': 'S'},
          {'attempt': 1, 'event': 2, 'kind': 'G'},
          {'attempt': 1, 'event': 3, 'kind': 'R', 'slipEvent': null, 'message': 'Efeito recusado'},
          {'attempt': 1, 'event': 4, 'kind': 'R', 'slipEvent': null},
        ]);
      expect(slip.refusedEffects.map((e) => e.event), [3, 4]);
      expect(slip.hasLiveRegistration, isFalse, reason: 'R é final mesmo recusado');
    });

    test('Equatable: registrations entram na identidade do detalhe', () {
      final a = BankSlipFull.fromJson(base());
      final b = BankSlipFull.fromJson(base()
        ..['registrations'] = [
          {'attempt': 1, 'requestCode': 'a', 'lastKind': 'G'},
        ]);
      expect(a == b, isFalse);
      expect(BankSlipFull.fromJson(base()) == a, isTrue);
    });
  });

  group('resultados das ações no banco', () {
    test('BankSlipRegisterResult lê tentativa, código e ambiente', () {
      final r = BankSlipRegisterResult.fromJson(
          {'attempt': 3, 'requestCode': 'req-9', 'environment': 'P'});
      expect(r.attempt, 3);
      expect(r.requestCode, 'req-9');
      expect(r.environment, 'P');
      expect(BankSlipRegisterResult.fromJson({}).environment, 'S');
    });

    test('BankSlipRefreshResult: sem mudança × liquidado × efeito recusado', () {
      expect(BankSlipRefreshResult.fromJson({'changed': false}).changed, isFalse);

      final settled = BankSlipRefreshResult.fromJson(
          {'changed': true, 'kind': 'R', 'bankStatus': 'RECEBIDO', 'slipEvent': 2});
      expect(settled.changed, isTrue);
      expect(settled.kind, 'R');
      expect(settled.slipEvent, 2);
      expect(settled.effectRefused, isNull);

      final refused = BankSlipRefreshResult.fromJson({
        'changed': true, 'kind': 'R', 'bankStatus': 'RECEBIDO',
        'slipEvent': null, 'effectRefused': 'BANK_SLIP_NOT_OPEN',
      });
      expect(refused.slipEvent, isNull);
      expect(refused.effectRefused, 'BANK_SLIP_NOT_OPEN');
    });

    test('BankSlipBankSyncReport conta erros pelo tamanho da lista', () {
      final rep = BankSlipBankSyncReport.fromJson({
        'checked': 8, 'changed': 2, 'reconciled': 1,
        'errors': [
          {'id': 1, 'code': 'BANK_UNAVAILABLE'},
          {'id': 2, 'code': 'BANK_UNAVAILABLE'},
        ],
        'stoppedEarly': true,
      });
      expect(rep.checked, 8);
      expect(rep.changed, 2);
      expect(rep.reconciled, 1);
      expect(rep.errors, 2);
      expect(rep.stoppedEarly, isTrue);

      final empty = BankSlipBankSyncReport.fromJson({});
      expect(empty.errors, 0);
      expect(empty.stoppedEarly, isFalse);
    });
  });
}
