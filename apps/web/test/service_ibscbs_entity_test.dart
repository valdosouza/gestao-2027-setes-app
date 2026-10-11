// Contrato de dados da aba IBS/CBS do cadastro de Serviços (fase IBS/CBS,
// D-IB6): GET /api/services/:id devolve `nbs`/`nbsDescription` e `ibscbs`
// ({classificationCode, cst derivado, classificationName, placeIndicatorCode,
// placeIndicatorDescription} | null); POST/PUT recebem `nbs` e `ibscbs`
// ({classificationCode, placeIndicatorCode} | null) — esta tela SEMPRE manda
// os dois (null = remove). Os DOIS códigos da classificação vão JUNTOS.

import 'package:flutter_test/flutter_test.dart';
import 'package:setes_web/app/modules/services/domain/entity/service_entity.dart';
import 'package:setes_web/app/modules/services/domain/service_ibscbs_rules.dart';

Map<String, dynamic> _service(Map<String, dynamic> extra) => {
      'id': 24,
      'identifier': '24',
      'description': 'Suporte técnico',
      'categoryId': 3,
      'active': 'S',
      'prices': const [],
      ...extra,
    };

void main() {
  group('ServiceFull.fromJson — IBS/CBS', () {
    test('lê NBS e a classificação com o CST vindo da API', () {
      final s = ServiceFull.fromJson(_service({
        'nbs': '115022000',
        'nbsDescription': 'Serviços de suporte em TI',
        'ibscbs': {
          'classificationCode': '000001',
          'cst': '000',
          'classificationName': 'Situações tributadas integralmente',
          'placeIndicatorCode': '100301',
          'placeIndicatorDescription': 'Demais serviços, em operações onerosas',
        },
      }));
      expect(s.nbs, '115022000');
      expect(s.nbsDescription, 'Serviços de suporte em TI');
      expect(s.nbsDisplay, '115022000 — Serviços de suporte em TI');
      final c = s.ibscbs!;
      expect(c.classificationCode, '000001', reason: 'zero à esquerda preservado');
      expect(c.cst, '000');
      expect(c.placeIndicatorCode, '100301');
      // Exibição no MESMO formato das listas de apoio da API.
      expect(c.classificationDisplay,
          '000 · 000001 — Situações tributadas integralmente');
      expect(c.placeIndicatorDisplay,
          '100301 — Demais serviços, em operações onerosas');
    });

    test('sem classificação: ibscbs null, NBS null e exibição vazia', () {
      final s = ServiceFull.fromJson(
          _service({'nbs': null, 'nbsDescription': null, 'ibscbs': null}));
      expect(s.nbs, isNull);
      expect(s.nbsDisplay, '');
      expect(s.ibscbs, isNull);
    });

    test('API antiga (campos ausentes) não quebra o form', () {
      final s = ServiceFull.fromJson(_service({}));
      expect(s.nbs, isNull);
      expect(s.ibscbs, isNull);
    });

    test('CST ausente é derivado do cClassTrib (3 primeiros dígitos)', () {
      final c = ServiceIbscbs.fromJson({
        'classificationCode': '200052',
        'placeIndicatorCode': '010101',
      });
      expect(c.cst, '200');
      expect(c.classificationDisplay, '200 · 200052');
      expect(c.placeIndicatorDisplay, '010101');
    });
  });

  group('ServiceCodeLookup.fromJson', () {
    test('chave `code` TEXTUAL e description pronta para exibir', () {
      final l = ServiceCodeLookup.fromJson(
          {'code': '000001', 'description': '000 · 000001 — Integral'});
      expect(l.code, '000001');
      expect(l.display, '000 · 000001 — Integral');
    });

    test('sem description exibe o código', () {
      final l = ServiceCodeLookup.fromJson({'code': '100301'});
      expect(l.display, '100301');
    });
  });

  group('ServiceInput.toJson — IBS/CBS', () {
    const base = ServiceInput(description: 'Suporte', categoryId: 3);

    test('SEMPRE envia nbs e ibscbs — null quando vazios (a API remove)', () {
      final json = base.toJson();
      expect(json.containsKey('nbs'), isTrue);
      expect(json['nbs'], isNull);
      expect(json.containsKey('ibscbs'), isTrue);
      expect(json['ibscbs'], isNull);
    });

    test('envia NBS e o PAR da classificação', () {
      const input = ServiceInput(
        description: 'Suporte',
        categoryId: 3,
        nbs: '115022000',
        ibscbs: ServiceIbscbsInput(
            classificationCode: '000001', placeIndicatorCode: '100301'),
      );
      final json = input.toJson();
      expect(json['nbs'], '115022000');
      expect(json['ibscbs'],
          {'classificationCode': '000001', 'placeIndicatorCode': '100301'});
    });
  });

  group('Regra local: os dois códigos da classificação vão JUNTOS', () {
    test('nenhum dos dois: sem pendência e payload null', () {
      expect(ibscbsClassificationPendency(null, null), isNull);
      expect(ibscbsPlaceIndicatorPendency(null, null), isNull);
      expect(ibscbsInputOf(null, null), isNull);
      expect(ibscbsInputOf('', '  '), isNull);
    });

    test('os dois: sem pendência e payload com o par', () {
      expect(ibscbsClassificationPendency('000001', '100301'), isNull);
      expect(ibscbsPlaceIndicatorPendency('000001', '100301'), isNull);
      expect(
          ibscbsInputOf('000001', '100301'),
          const ServiceIbscbsInput(
              classificationCode: '000001', placeIndicatorCode: '100301'));
    });

    test('só o indicador: pendência ancorada na CLASSIFICAÇÃO', () {
      expect(ibscbsClassificationPendency(null, '100301'),
          ibscbsClassificationRequiredKey);
      expect(ibscbsPlaceIndicatorPendency(null, '100301'), isNull);
      expect(ibscbsInputOf(null, '100301'), isNull,
          reason: 'meio par nunca vai para a API');
    });

    test('só a classificação: pendência ancorada no INDICADOR', () {
      expect(ibscbsClassificationPendency('000001', ''), isNull);
      expect(ibscbsPlaceIndicatorPendency('000001', ''),
          ibscbsPlaceIndicatorRequiredKey);
      expect(ibscbsInputOf('000001', ''), isNull);
    });

    test('NBS vazia vira null; preenchida passa aparada', () {
      expect(nbsInputOf(null), isNull);
      expect(nbsInputOf(' '), isNull);
      expect(nbsInputOf('115022000'), '115022000');
    });
  });

  group('Derivações de exibição', () {
    test('CST = 3 primeiros dígitos do cClassTrib', () {
      expect(deriveIbscbsCst('000001'), '000');
      expect(deriveIbscbsCst('410014'), '410');
    });

    test('avatares das listas: capítulo da NBS e grupo do cIndOp', () {
      expect(nbsAvatar('101011100'), '1.01');
      expect(placeIndicatorAvatar('100301'), '10');
      expect(placeIndicatorAvatar('010101'), '01');
    });
  });

  // D-IB29 (Rodada 3, Valdo 2026-10-10): o cadastro aceita classificação com início
  // futuro até a obrigação; a tela mostra "vale a partir de" (e "vale de … até …").
  group('vigência da classificação (D-IB29)', () {
    test('GET e lista trazem validFrom/validUntil', () {
      final s = ServiceIbscbs.fromJson({
        'classificationCode': '000009', 'cst': '000', 'classificationName': 'n',
        'validFrom': '2027-01-01', 'validUntil': null,
        'placeIndicatorCode': '100301',
      });
      expect(s.validFrom, '2027-01-01');
      expect(s.validUntil, isNull);
      final l = ServiceCodeLookup.fromJson({
        'code': '000009', 'description': 'x', 'validFrom': '2027-01-01', 'validUntil': '2027-12-31',
      });
      expect([l.validFrom, l.validUntil], ['2027-01-01', '2027-12-31']);
      expect(ServiceCodeLookup.fromJson({'code': '100301'}).validFrom, isNull);
    });

    test('texto: só início → "vale a partir de"; com fim → "vale de … até …"; sem início → nada', () {
      final from = ibscbsValidity('2027-01-01', null)!;
      expect(from.key, ibscbsValidFromKey);
      expect(from.args, ['01/01/2027']);
      final range = ibscbsValidity('2026-01-01', '2026-10-01')!;
      expect(range.key, ibscbsValidRangeKey);
      expect(range.args, ['01/01/2026', '01/10/2026']);
      expect(ibscbsValidity(null, null), isNull);
      expect(ibscbsBrDate('lixo'), isNull);
    });
  });

  test('lista do cClassTrib: só a que começa DEPOIS de hoje leva "vale a partir de" (D-IB29)', () {
    final today = DateTime(2026, 10, 10);
    final future = ibscbsFutureValidity('2027-01-01', today)!;
    expect(future.key, ibscbsValidFromKey);
    expect(future.args, ['01/01/2027']);
    expect(ibscbsFutureValidity('2026-01-01', today), isNull);
    expect(ibscbsFutureValidity('2026-10-10', today), isNull);
    expect(ibscbsFutureValidity(null, today), isNull);
  });

  test('GET traz acceptedToday (D-IB37 — o selo da aba); ausente = não avaliado', () {
    ServiceIbscbs parse(Object? v) => ServiceIbscbs.fromJson({
          'classificationCode': '000006', 'cst': '000', 'placeIndicatorCode': '100301',
          if (v != null) 'acceptedToday': v,
        });
    expect(parse(false).acceptedToday, isFalse);
    expect(parse(true).acceptedToday, isTrue);
    expect(parse(null).acceptedToday, isNull);
  });

  test('selo por componente (D-IB37): cada código traz o próprio aceite', () {
    final s = ServiceIbscbs.fromJson({
      'classificationCode': '000001', 'cst': '000', 'placeIndicatorCode': '100302',
      'acceptedToday': false, 'classificationAcceptedToday': true, 'placeIndicatorAcceptedToday': false,
    });
    expect([s.acceptedToday, s.classificationAcceptedToday, s.placeIndicatorAcceptedToday], [false, true, false]);
  });
}
