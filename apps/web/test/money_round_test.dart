// M2 do socrático da Rodada 5 (cancelamento de nota, 2026-09-11): a tela arredonda
// dinheiro pela MESMA regra da API/DECIMAL (half-up sobre o decimal escrito).
import 'package:flutter_test/flutter_test.dart';
import 'package:setes_web/app/shared/format/money.dart';

void main() {
  test('half-up do DECIMAL: 0,145 (5,80 × 2,5 %) → 0,15; 9,995 → 10,00; 1,005 → 1,01', () {
    expect(roundMoney(5.80 * 2.5 / 100), 0.15);
    expect(roundMoney(9.995), 10.0);
    expect(roundMoney(1.005), 1.01);
    expect(toCents(9.995), 1000);
  });
  test('valores em 2 casas ficam iguais; 3ª casa abaixo de 5 cai; ruído binário some', () {
    expect(roundMoney(33.33), 33.33);
    expect(roundMoney(10.004), 10.0);
    expect(roundMoney(0.1 + 0.2), 0.3);
    expect(setesMoney(0.145), r'R$ 0,15');
  });
}
