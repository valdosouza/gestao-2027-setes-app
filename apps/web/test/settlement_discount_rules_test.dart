// Regras do desconto da baixa na TELA (D-G28 desconto sobre o SALDO, D-G32 teto ×
// privilégio, D-G35 nunca cobre o saldo inteiro) — espelho do que a API aceita.
import 'package:flutter_test/flutter_test.dart';
import 'package:setes_web/app/modules/settlements/domain/settlement_discount_rules.dart';

void main() {
  group('discountGranted (D-G28 + D-G35)', () {
    test('% incide sobre o SALDO em aberto, não sobre o valor original', () {
      expect(discountGranted(40, 10), 4);
      expect(discountGranted(100, 2.5), 2.5);
    });
    test('nunca cobre o saldo inteiro — sobra ao menos 1 centavo', () {
      expect(discountGranted(10, 99.99), 9.99);
      expect(discountGranted(10, 100), 9.99);
      expect(discountGranted(0.01, 99.99), 0);
    });
    test('sem alíquota ou sem saldo, nada é concedido', () {
      expect(discountGranted(100, 0), 0);
      expect(discountGranted(0, 10), 0);
    });
  });

  group('suggestedLiquid', () {
    test('saldo + juros + multa − desconto concedido', () {
      expect(
          suggestedLiquid(
              balance: 100, interestValue: 5, lateValue: 2, discountAliquot: 10),
          97);
    });
    test('99,99 % de 10,00 sugere 0,01 (o que a API aceita), nunca 0,00', () {
      expect(
          suggestedLiquid(
              balance: 10, interestValue: 0, lateValue: 0, discountAliquot: 99.99),
          0.01);
    });
  });

  group('discountPendency (D-G32)', () {
    test('sem o privilégio: dentro do teto passa, acima acusa', () {
      expect(discountPendency(5, maxDiscount: 5, canDiscount: false), isNull);
      expect(discountPendency(5.01, maxDiscount: 5, canDiscount: false), 'aboveLimit');
      expect(discountPendency(0.01, maxDiscount: 0, canDiscount: false), 'aboveLimit');
    });
    test('com o privilégio DESCONTO o teto não vale, mas 100 % continua morto', () {
      expect(discountPendency(50, maxDiscount: 0, canDiscount: true), isNull);
      expect(discountPendency(100, maxDiscount: 0, canDiscount: true),
          'forms.settlement.discountInvalid');
    });
    test('valor ilegível ou negativo é pendência de formato', () {
      expect(discountPendency(null, maxDiscount: 10, canDiscount: true),
          'forms.settlement.discountInvalid');
      expect(discountPendency(-1, maxDiscount: 10, canDiscount: true),
          'forms.settlement.discountInvalid');
    });
  });
}
