import 'package:flutter/services.dart';

/// Máscaras do padrão técnico da casa (decisão 16 da Fase 2):
/// `#` = dígito, `A` = letra, qualquer outro caractere é literal (inserido
/// automaticamente na digitação). Dados NUNCA gravam a máscara (decisão 19):
/// use [unmask] antes de enviar à API.

/// Valor completo casa com a máscara? (espelho do matchesMask da API)
bool matchesMask(String mask, String value) {
  if (mask.isEmpty) return true;
  if (mask.length != value.length) return false;
  for (var i = 0; i < mask.length; i++) {
    final m = mask[i];
    final c = value[i];
    if (m == '#') {
      if (!RegExp(r'\d').hasMatch(c)) return false;
    } else if (m == 'A') {
      if (!RegExp(r'[a-zA-ZÀ-ÿ]').hasMatch(c)) return false;
    } else if (m != c) {
      return false;
    }
  }
  return true;
}

/// Remove os literais da máscara: mantém apenas dígitos e letras
/// (o que o usuário digitou de fato — é isso que vai para a API).
String unmask(String value) =>
    value.replaceAll(RegExp(r'[^0-9a-zA-ZÀ-ÿ]'), '');

/// Formatter de digitação guiada pela máscara `#`/`A` — insere os literais
/// automaticamente e bloqueia caracteres fora do padrão da posição.
class SetesMaskFormatter extends TextInputFormatter {
  SetesMaskFormatter(this.mask);

  final String mask;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (mask.isEmpty) return newValue;

    final raw = unmask(newValue.text);
    final buffer = StringBuffer();
    var rawIndex = 0;

    for (var i = 0; i < mask.length && rawIndex < raw.length; i++) {
      final m = mask[i];
      if (m == '#') {
        // consome o próximo dígito; caractere inválido é descartado
        while (rawIndex < raw.length && !RegExp(r'\d').hasMatch(raw[rawIndex])) {
          rawIndex++;
        }
        if (rawIndex < raw.length) buffer.write(raw[rawIndex++]);
      } else if (m == 'A') {
        while (rawIndex < raw.length &&
            !RegExp(r'[a-zA-ZÀ-ÿ]').hasMatch(raw[rawIndex])) {
          rawIndex++;
        }
        if (rawIndex < raw.length) buffer.write(raw[rawIndex++]);
      } else {
        buffer.write(m);
      }
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
