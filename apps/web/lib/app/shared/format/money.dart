/// Moeda pt-BR 'R$ 1.234,56' — formato de moeda é a única string visível
/// fora do i18n (decisão da entrega do Módulo Software House, 2026-07-18).
/// Nasceu no módulo contracts (contractMoney) e foi promovida para shared
/// no 2º consumidor (service_orders — regra de promoção da
/// ARQUITETURA_MODULOS.md, 2026-07-19).
String setesMoney(double value) {
  final negative = value < 0;
  final cents = (value.abs() * 100).round();
  final units = (cents ~/ 100).toString();
  final frac = (cents % 100).toString().padLeft(2, '0');
  final grouped = StringBuffer();
  for (var i = 0; i < units.length; i++) {
    if (i > 0 && (units.length - i) % 3 == 0) grouped.write('.');
    grouped.write(units[i]);
  }
  return '${negative ? '-' : ''}R\$ $grouped,$frac';
}
