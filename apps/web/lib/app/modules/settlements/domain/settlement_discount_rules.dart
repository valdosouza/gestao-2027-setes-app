import '../../../shared/format/money.dart';

/// Regras do DESCONTO da baixa na TELA — espelho do que a API aceita
/// (D-G28/D-G32/D-G35 do cancelamento de nota). Ficam FORA do widget para
/// poderem ser testadas e para a regra ter um lugar só no app.
///
/// A API é quem decide (peça `title-balance` + `assertDiscountPolicy`); aqui
/// só antecipamos a recusa para o usuário não descobrir no 403/409.

/// Teto absoluto do percentual — D-G35: desconto de 100 % não existe.
const double kMaxDiscountAliquot = 99.99;

/// Desconto CONCEDIDO por uma baixa: % sobre o SALDO em aberto no ato (D-G28),
/// limitado a `saldo − 0,01` (D-G35: sempre sobra ao menos 1 centavo a receber —
/// 99,99 % de 10,00 daria 9,999, que o DECIMAL arredondaria para 10,00).
double discountGranted(double balance, double aliquot) {
  if (!(aliquot > 0) || !(balance > 0)) return 0;
  final wanted = roundMoney(balance * aliquot / 100);
  final max = balance >= 0.01 ? roundMoney(balance - 0.01) : 0.0;
  return wanted < max ? wanted : max;
}

/// Líquido sugerido no dialog: saldo + juros + multa − desconto concedido.
double suggestedLiquid({
  required double balance,
  required double interestValue,
  required double lateValue,
  required double discountAliquot,
}) =>
    roundMoney(balance +
        interestValue +
        lateValue -
        discountGranted(balance, discountAliquot));

/// Pendência do campo de desconto, ou null se está válido.
/// [maxDiscount] = teto da empresa (config `max_discount_aliquot`);
/// [canDiscount] = usuário tem o privilégio DESCONTO (bypassa o teto).
/// Devolve a CHAVE i18n (ou o texto já formatado do teto) — o chamador traduz.
String? discountPendency(double? value,
    {required double maxDiscount, required bool canDiscount}) {
  if (value == null || value < 0 || value > kMaxDiscountAliquot) {
    return 'forms.settlement.discountInvalid';
  }
  if (!canDiscount && value > maxDiscount + 1e-9) return 'aboveLimit';
  return null;
}
