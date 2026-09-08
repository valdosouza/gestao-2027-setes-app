/// Helpers de formato da negociação e dos cheques do pedido (molde
/// check_format.dart do módulo checks): decimais digitados com vírgula
/// (pt-BR), comparação de dinheiro em CENTAVOS (nunca double == double) e
/// data ISO 'yyyy-MM-dd' a partir de [DateTime].
library;

/// 1234.5 → '1234,50' (2 casas, vírgula) — texto dos campos de valor.
String orderDecimalText(double value) =>
    value.toStringAsFixed(2).replaceAll('.', ',');

/// '1234,50' | '1234.50' → 1234.5 (null se não parseia).
double? orderParseDecimal(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));

/// Valor em centavos inteiros — a soma × base e a soma dos cheques ×
/// parcela comparam AQUI (o servidor compara em round2; aqui é o espelho).
int orderCents(double value) => (value * 100).round();

/// true quando [value] tem no máximo 2 casas decimais (regra do DTO:
/// amount/value do servidor recusam 3ª casa).
bool orderHasTwoDecimals(double value) =>
    (value * 100 - (value * 100).roundToDouble()).abs() < 1e-9;

/// [DateTime] → ISO 'yyyy-MM-dd' (o que a API trafega).
String orderIsoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Hoje em ISO — default de datas dos dialogs.
String orderTodayIso() => orderIsoDate(DateTime.now());

/// ISO + [days] → ISO (sugestão de vencimento da parcela adicionada).
String orderIsoAddDays(String iso, int days) {
  final base = DateTime.tryParse(iso) ?? DateTime.now();
  return orderIsoDate(base.add(Duration(days: days)));
}
