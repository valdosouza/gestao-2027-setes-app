// Contrato de dados do Meu Estabelecimento (módulo establishment) — campos
// do EMITENTE da NFS-e (Onda 3, §9.3 da prompt_onda_nfe_sefaz.md):
// simplesRegime (opSimpNac), specialTaxRegime (regEspTrib) e cnae chegam no
// GET e viajam no PUT ao lado do taxRegime — null = limpa.

import 'package:flutter_test/flutter_test.dart';
import 'package:setes_web/app/modules/establishment/domain/entity/object_establishment.dart';

void main() {
  group('ObjectEstablishment.fromJson', () {
    test('lê os campos do emitente (string ou número)', () {
      final e = ObjectEstablishment.fromJson({
        'nameCompany': 'SETES LTDA',
        'nickTrade': 'Setes',
        'document': '12345678000199',
        'taxRegime': '1 - Simples Nacional',
        'simplesRegime': 3,
        'simplesAssessment': 2,
        'specialTaxRegime': '0',
        'cnae': '6201501',
      });
      expect(e.simplesRegime, '3');
      expect(e.simplesAssessment, '2');
      expect(e.toJson()['simplesAssessment'], '2');
      // D-N19a: fora do ME/EPP a apuração não viaja (null limpa)
      expect(e.copyWith(simplesRegime: '1').toJson()['simplesAssessment'], isNull);
      expect(e.specialTaxRegime, '0');
      expect(e.cnae, '6201501');
      expect(e.taxRegime, '1 - Simples Nacional');
    });

    test('ausentes/vazios viram null', () {
      final e = ObjectEstablishment.fromJson({
        'nameCompany': 'X',
        'simplesRegime': null,
        'cnae': '',
      });
      expect(e.simplesRegime, isNull);
      expect(e.specialTaxRegime, isNull);
      expect(e.cnae, isNull);
    });
  });

  group('ObjectEstablishment.toJson (PUT)', () {
    test('sempre envia os três campos; preenchidos viajam como string', () {
      final json = const ObjectEstablishment(
        nameCompany: 'SETES LTDA',
        nickTrade: 'Setes',
        simplesRegime: '2',
        specialTaxRegime: '5',
        cnae: '6201501',
      ).toJson();
      expect(json['simplesRegime'], '2');
      expect(json['specialTaxRegime'], '5');
      expect(json['cnae'], '6201501');
      expect(json.containsKey('document'), isFalse, reason: 'documento é só exibição');
    });

    test('vazio ("" — usuário limpou) e null viajam como null (limpa na API)', () {
      final json = const ObjectEstablishment(
        nameCompany: 'X',
        nickTrade: 'Y',
        simplesRegime: '',
        specialTaxRegime: null,
        cnae: '  ',
      ).toJson();
      expect(json.containsKey('simplesRegime'), isTrue);
      expect(json['simplesRegime'], isNull);
      expect(json['specialTaxRegime'], isNull);
      expect(json['cnae'], isNull);
    });
  });

  test('copyWith aceita "" para limpar um regime escolhido antes', () {
    const original = ObjectEstablishment(simplesRegime: '3', cnae: '6201501');
    final cleared = original.copyWith(simplesRegime: '');
    expect(cleared.simplesRegime, '');
    expect(cleared.toJson()['simplesRegime'], isNull);
    expect(cleared.cnae, '6201501', reason: 'campo não tocado é preservado');
  });
}
