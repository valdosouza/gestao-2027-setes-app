// Contrato de dados das Regras de Tributação de Serviço — código de
// tributação NACIONAL (cTribNac, Onda 3 NFS-e): a regra traz o gravado
// (`nationalCode`), o efetivo (`effectiveNationalCode` — gravado ou
// derivado) e quantos desdobros o item tem (`nationalCodeOptions`); o
// POST/PUT manda `nationalCode` null quando derivado.

import 'package:flutter_test/flutter_test.dart';
import 'package:setes_web/app/modules/service_tax_rules/domain/entity/service_tax_rule_entity.dart';

void main() {
  group('ServiceTaxRuleEntity', () {
    test('fromJson lê os campos do código nacional', () {
      final r = ServiceTaxRuleEntity.fromJson({
        'id': 7,
        'cityId': 4106902,
        'cityName': 'Curitiba',
        'stateAbbreviation': 'PR',
        'serviceListId': '1.02',
        'serviceListDescription': 'Programação',
        'aliq': '2.00',
        'nationalCode': '010202',
        'effectiveNationalCode': '010202',
        'nationalCodeOptions': 3,
      });
      expect(r.nationalCode, '010202');
      expect(r.effectiveNationalCode, '010202');
      expect(r.nationalCodeOptions, 3);
      expect(r.nationalCodeDerived, isFalse, reason: 'há código GRAVADO');
    });

    test('derivado: nada gravado, efetivo vindo do item com um desdobro', () {
      final r = ServiceTaxRuleEntity.fromJson({
        'id': 8,
        'cityId': 1,
        'serviceListId': '1.05',
        'aliq': 5,
        'nationalCode': null,
        'effectiveNationalCode': 10501, // número → normalizado para string
        'nationalCodeOptions': '1',
      });
      expect(r.nationalCode, isNull);
      expect(r.effectiveNationalCode, '10501');
      expect(r.nationalCodeOptions, 1);
      expect(r.nationalCodeDerived, isTrue);
    });

    test('item sem código nacional no catálogo: tudo null/0 e não derivado', () {
      final r = ServiceTaxRuleEntity.fromJson({
        'id': 9,
        'cityId': 1,
        'serviceListId': '9.99',
        'aliq': 0,
      });
      expect(r.nationalCode, isNull);
      expect(r.effectiveNationalCode, isNull);
      expect(r.nationalCodeOptions, 0);
      expect(r.nationalCodeDerived, isFalse);
    });
  });

  group('ServiceTaxRuleInput.toJson', () {
    test('sempre envia nationalCode — null quando derivado', () {
      final derived = const ServiceTaxRuleInput(
        cityId: 1,
        serviceListId: '1.05',
        aliq: 5,
      ).toJson();
      expect(derived.containsKey('nationalCode'), isTrue);
      expect(derived['nationalCode'], isNull);

      final chosen = const ServiceTaxRuleInput(
        cityId: 1,
        serviceListId: '1.02',
        aliq: 2,
        nationalCode: '010203',
      ).toJson();
      expect(chosen['nationalCode'], '010203');
    });
  });

  group('NationalCodeLookup', () {
    test('fromJson + display + sequence (desdobro = 2 últimos dígitos)', () {
      final o = NationalCodeLookup.fromJson({
        'id': '010203',
        'description': 'Programação de sistemas sob encomenda',
      });
      expect(o.display, '010203 - Programação de sistemas sob encomenda');
      expect(o.sequence, 3);
    });

    test('sem descrição exibe só o código; id curto não quebra', () {
      expect(const NationalCodeLookup(id: '010201').display, '010201');
      expect(const NationalCodeLookup(id: '7').sequence, 7);
      expect(const NationalCodeLookup(id: '').sequence, 0);
    });
  });
}
