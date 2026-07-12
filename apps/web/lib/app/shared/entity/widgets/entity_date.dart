import 'package:easy_localization/easy_localization.dart';

/// Conversões de data das abas da cadeia de entidade fiscal.
/// A API trafega ISO 'yyyy-MM-dd'; a UI digita/exibe 'dd/mm/aaaa'.

/// ISO 'yyyy-MM-dd' → 'dd/MM/yyyy' ('' se nulo/ inválido).
String isoDateToDisplay(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final parts = iso.split('-');
  if (parts.length != 3) return '';
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}

/// 'dd/MM/yyyy' → ISO 'yyyy-MM-dd' (null se vazio ou inválido).
String? displayDateToIso(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(t);
  if (match == null) return null;
  final day = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final year = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  // DateTime "corrige" 32/01 para 01/02 — rejeita se não bateu.
  if (date.day != day || date.month != month || date.year != year) return null;
  return '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}

/// Validator de data OPCIONAL (vazio ok; preenchido precisa ser válido).
String? validateOptionalDate(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  return displayDateToIso(text) == null ? 'register.invalidDate'.tr() : null;
}
