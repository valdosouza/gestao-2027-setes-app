/// Moeda pt-BR 'R$ 1.234,56' — formato de moeda é a única string visível
/// fora do i18n (decisão da entrega do Módulo Software House, 2026-07-18).
/// Nasceu no módulo contracts (contractMoney) e foi promovida para shared
/// no 2º consumidor (service_orders — regra de promoção da
/// ARQUITETURA_MODULOS.md, 2026-07-19).
String setesMoney(double value) {
  final negative = value < 0;
  final cents = toCents(value.abs());
  final units = (cents ~/ 100).toString();
  final frac = (cents % 100).toString().padLeft(2, '0');
  final grouped = StringBuffer();
  for (var i = 0; i < units.length; i++) {
    if (i > 0 && (units.length - i) % 3 == 0) grouped.write('.');
    grouped.write(units[i]);
  }
  return '${negative ? '-' : ''}R\$ $grouped,$frac';
}

/// Centavos inteiros pela MESMA regra do DECIMAL(…,2) do banco e da peça
/// `@shared/money` da API (Q-A27 / M2 do socrático da Rodada 5 do
/// cancelamento de nota, 2026-09-11): half-up sobre a representação decimal
/// curta do double — `(v * 100).roundToDouble()` dava 14 para 0,145 (que em
/// binário é 0,14499…) enquanto a API grava 0,15; a sugestão da tela caía
/// em 409 por 1 centavo. O que a tela sugere é o que a API aceita.
int toCents(double value) {
  if (!value.isFinite) return 0;
  return double.parse((value * 100).toStringAsPrecision(15)).round();
}

/// Valor em 2 casas pela regra do DECIMAL (espelho de `round2` da API).
double roundMoney(double value) => toCents(value) / 100;
