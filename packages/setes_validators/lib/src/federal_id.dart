/// INSCRIÇÃO FEDERAL (CPF/CNPJ) — espelho Dart da peça `fiscal-api/federal-id` (frente do CNPJ alfanumérico, D-CJ2 = Q-CJ2 (a),
/// Valdo 2026-10-15; `Infra-IA/prompts/prompt_frente_cnpj_alfanumerico.md` §4.2).
///
/// A regra tem UMA fonte (o TS do núcleo); este espelho é garantido pelo MESMO vetor de casos
/// (`fiscal-api/src/federal-id/federal-id.vector.json`), lido pela suíte Dart (`test/federal_id_test.dart`) e pela TS.
///
/// - CNPJ: 12 posições `[0-9A-Z]` (letras MAIÚSCULAS) + 2 DV numéricos; nenhuma letra proibida; CNPJ novo pode ser numérico.
/// - DV: cada caractere vale ASCII − 48; pesos 2…9 da direita para a esquerda, recomeçando; módulo 11; resto 0 ou 1 → 0, senão
///   11 − resto (para CNPJ numérico dá o cálculo de sempre).
/// - NORMALIZAR = canonicalizar, NUNCA apagar: tira só `.` `/` `-` e espaço, sobe `a–z` (só ASCII) para `A–Z`; qualquer outro
///   caractere torna o valor inválido.
/// - PF × PJ vem do LUGAR (toggle triplo, especialização), nunca do comprimento depois de limpar.
library;

enum FederalIdKind { cpf, cnpj }

/// A inscrição com o tipo junto — o tipo vem do LUGAR.
class FederalId {
  const FederalId._(this.kind, this.value);

  final FederalIdKind kind;

  /// Forma canônica: CNPJ `[0-9A-Z]{12}[0-9]{2}`, CPF `[0-9]{11}`.
  final String value;

  /// Só de valor VÁLIDO na forma canônica; senão null.
  static FederalId? of(FederalIdKind kind, String? value) {
    if (value == null) return null;
    final ok = kind == FederalIdKind.cnpj ? FederalIdRules.isValidCnpj(value) : FederalIdRules.isValidCpf(value);
    return ok ? FederalId._(kind, value) : null;
  }

  @override
  bool operator ==(Object other) => other is FederalId && other.kind == kind && other.value == value;

  @override
  int get hashCode => Object.hash(kind, value);

  @override
  String toString() => kind == FederalIdKind.cnpj ? FederalIdRules.formatCnpj(value) : FederalIdRules.formatCpf(value);
}

/// Funções puras da inscrição federal — os MESMOS algoritmos da peça TS do núcleo.
class FederalIdRules {
  const FederalIdRules._();

  /// Forma canônica do CNPJ (RFB, IN 2.229/2024).
  static final RegExp cnpjForm = RegExp(r'^[0-9A-Z]{12}[0-9]{2}$');

  /// Forma canônica do CPF.
  static final RegExp cpfForm = RegExp(r'^[0-9]{11}$');

  static final RegExp _acceptedInput = RegExp(r'^[0-9A-Za-z./\- ]*$');

  /// Primitiva do módulo 11 com valor ASCII − 48. Só `[0-9A-Z]` (lança [ArgumentError] no resto).
  static int mod11Ascii48(String chars) {
    if (!RegExp(r'^[0-9A-Z]+$').hasMatch(chars)) throw ArgumentError('mod11Ascii48: só [0-9A-Z]');
    var sum = 0;
    var weight = 2;
    for (var i = chars.length - 1; i >= 0; i--) {
      sum += (chars.codeUnitAt(i) - 48) * weight;
      weight = weight == 9 ? 2 : weight + 1;
    }
    final rest = sum % 11;
    return rest < 2 ? 0 : 11 - rest;
  }

  /// Os dois DV de 12 posições `[0-9A-Z]`; null se as 12 posições não têm a forma.
  static String? cnpjCheckDigits(String base12) {
    if (!RegExp(r'^[0-9A-Z]{12}$').hasMatch(base12)) return null;
    final d1 = mod11Ascii48(base12);
    final d2 = mod11Ascii48('$base12$d1');
    return '$d1$d2';
  }

  /// Canonicaliza um texto de inscrição (trim, tira só a máscara, sobe a–z); null se houver QUALQUER outro caractere.
  static String? canonicalizeText(String? raw) {
    if (raw == null) return null;
    // gate adversarial da onda 0 (LOW): o `String.trim()` do Dart apara o NEL (U+0085) e o do JavaScript não — o espelho divergia. O `\s`
    // do RegExp do Dart segue o ECMAScript: aparar por ele = o `trim()` da peça TS (NBSP sai nos dois; NEL fica nos dois e invalida)
    final trimmed = raw.replaceAll(RegExp(r'^\s+|\s+$'), '');
    // o teste é sobre o texto CRU: toUpperCase de fora do ASCII viraria ASCII ('ı' → 'I') e entraria calado
    if (!_acceptedInput.hasMatch(trimmed)) return null;
    return trimmed.replaceAll(RegExp(r'[./\- ]'), '').toUpperCase();
  }

  /// Entrada → forma canônica do CNPJ (sem conferir o DV); null se não chega à forma.
  static String? normalizeCnpj(String? raw) {
    final c = canonicalizeText(raw);
    return c != null && cnpjForm.hasMatch(c) ? c : null;
  }

  /// Entrada → forma canônica do CPF (sem conferir o DV); null se não chega à forma.
  static String? normalizeCpf(String? raw) {
    final c = canonicalizeText(raw);
    return c != null && cpfForm.hasMatch(c) ? c : null;
  }

  /// CNPJ válido = JÁ na forma canônica + DV; veta só os 14 dígitos iguais.
  static bool isValidCnpj(String? value) {
    if (value == null || !cnpjForm.hasMatch(value)) return false;
    if (RegExp(r'^(\d)\1{13}$').hasMatch(value)) return false;
    return cnpjCheckDigits(value.substring(0, 12)) == value.substring(12);
  }

  /// CPF válido = JÁ na forma canônica + DV; veta os 11 iguais.
  static bool isValidCpf(String? value) {
    if (value == null || !cpfForm.hasMatch(value)) return false;
    if (RegExp(r'^(\d)\1{10}$').hasMatch(value)) return false;
    final digits = value.split('').map(int.parse).toList();
    for (final position in [9, 10]) {
      var sum = 0;
      for (var i = 0; i < position; i++) {
        sum += digits[i] * (position + 1 - i);
      }
      if (((sum * 10) % 11) % 10 != digits[position]) return false;
    }
    return true;
  }

  /// `XX.XXX.XXX/XXXX-DV` sobre CNPJ VÁLIDO; qualquer outro valor volta como veio.
  static String formatCnpj(String value) {
    if (!isValidCnpj(value)) return value;
    return '${value.substring(0, 2)}.${value.substring(2, 5)}.${value.substring(5, 8)}/'
        '${value.substring(8, 12)}-${value.substring(12)}';
  }

  /// `XXX.XXX.XXX-DV` sobre CPF VÁLIDO; qualquer outro valor volta como veio.
  static String formatCpf(String value) {
    if (!isValidCpf(value)) return value;
    return '${value.substring(0, 3)}.${value.substring(3, 6)}.${value.substring(6, 9)}-${value.substring(9)}';
  }
}
