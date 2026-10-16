// D-CJ8 (onda 1 da frente do CNPJ alfanumérico, 2026-10-16): o julgamento ÚNICO do CPF/CNPJ do formulário de entidade (marca inline do
// campo = pendência das 5 páginas — R3) e o objeto de domínio que guarda e envia a forma CANÔNICA (o `cnpjDigits` morreu — S2).
import 'package:flutter_test/flutter_test.dart';
import 'package:setes_web/app/shared/entity/domain/federal_id_check.dart';
import 'package:setes_web/app/shared/entity/domain/object_entity_fiscal.dart';

void main() {
  group('cnpjProblem / cpfProblem', () {
    test('vazio = faltando; válido (alfanumérico, com máscara ou minúsculo) = ok; DV errado ou lixo = inválido', () {
      expect(cnpjProblem(''), FederalIdProblem.missing);
      expect(cnpjProblem('   '), FederalIdProblem.missing);
      expect(cnpjProblem(null), FederalIdProblem.missing);
      for (final ok in ['PC3D315K000193', 'PC.3D3.15K/0001-93', 'pc3d315k000193', '12345678000195', '00000000E08G12']) {
        expect(cnpjProblem(ok), isNull, reason: ok);
      }
      for (final bad in ['12345678000199', 'PC3D315K000194', 'PC3D315K00019Z', '12ÁBC34501DE35', '1234567800019']) {
        expect(cnpjProblem(bad), FederalIdProblem.invalid, reason: bad);
      }
    });
    test('CPF segue numérico, com DV', () {
      expect(cpfProblem('529.982.247-25'), isNull);
      expect(cpfProblem('52998224724'), FederalIdProblem.invalid);
      expect(cpfProblem(''), FederalIdProblem.missing);
    });
  });

  group('objeto de domínio — envia a forma CANÔNICA, nunca mutilada', () {
    test('CNPJ digitado com máscara e minúscula sai canônico', () {
      expect(const CompanyData(cnpj: 'pc.3d3.15k/0001-93').toJson()['cnpj'], 'PC3D315K000193');
      expect(const CompanyData(cnpj: '12.345.678/0001-95').toJson()['cnpj'], '12345678000195');
    });
    test('CNPJ com 3 letras NÃO vira 11 dígitos (antes o `cnpjDigits` tirava as letras)', () {
      expect(const CompanyData(cnpj: 'ABC12345000110').toJson()['cnpj'], 'ABC12345000110');
    });
    test('fora da forma: vai como digitado (aparado) — a validação e a API acusam; nada some', () {
      expect(const CompanyData(cnpj: ' 12ÁBC34501DE35 ').toJson()['cnpj'], '12ÁBC34501DE35');
    });
    test('CPF canônico', () {
      expect(const PersonData(cpf: '529.982.247-25').toJson()['cpf'], '52998224725');
    });
  });
}
