import 'common_passwords.g.dart';

/// POLÍTICA DE SENHA — espelho de `setes-api/src/shared/auth/password-policy.ts` (Onda 3 do endurecer — D-EA5, D-EA13, D-EA16,
/// A-EA9; `Infra-IA/prompts/prompt_endurecer_autenticacao.md`). O MESMO julgamento e as MESMAS mensagens: o teste
/// `password_policy_test.dart` lê o VETOR de casos do setes-api ao lado e confere a lista ([commonPasswords]) entrada por entrada.
/// A API segue sendo a fonte da verdade (ela julga de novo e devolve `fields[]`); aqui é a ajuda na tela.
///
/// "Igual à atual" NÃO mora aqui: só a API conhece o hash e só julga depois do código conferido.
class PasswordPolicy {
  const PasswordPolicy._();

  static const int minLength = 8;
  static const int maxLength = 100;

  /// D-EA16: a parte local do e-mail só é julgada com 4+ caracteres.
  static const int emailLocalMinLength = 4;

  /// Problemas, na ordem de prioridade (o 1º é o que a tela mostra) — os MESMOS códigos da API.
  static const String blank = 'blank';
  static const String invalidChar = 'invalid-char';
  static const String tooShort = 'too-short';
  static const String tooLong = 'too-long';
  static const String common = 'common';
  static const String containsEmail = 'contains-email';

  /// Tabela explícita de acentos (a MESMA da API — o Dart não tem normalização Unicode no núcleo). Depois do `toLowerCase()`.
  static const Map<String, String> _accentFold = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n', 'ý': 'y', 'ÿ': 'y',
    'ς': 'σ', // sigma final — a MESMA dobra da API
  };

  /// "Branco" com a MESMA lista explícita da API (o `trim()` do Dart e o do JS divergem em U+0085 — gate adversarial da Onda 3).
  static const String _blank =
      '\\t\\n\\u000b\\f\\r \\u0085\\u00a0\\u1680\\u2000-\\u200a\\u2028\\u2029\\u202f\\u205f\\u3000\\ufeff';
  static final RegExp _onlyBlank = RegExp('^[$_blank]*\$');
  static final RegExp _edgeBlank = RegExp('^[$_blank]+|[$_blank]+\$');

  /// Marcas combinantes (U+0300–U+036F), retiradas DEPOIS do `toLowerCase()` — acento em NFD e o `İ` ficam iguais nas duas pontas.
  static final RegExp _combining = RegExp('[\\u0300-\\u036f]');

  static bool isBlank(String value) => _onlyBlank.hasMatch(value);

  /// D-EA39: caracteres invisíveis/de controle e meio emoji (substituto UTF-16 sem o par) — a MESMA lista da API, por unidade UTF-16.
  static const List<List<int>> _forbiddenUnits = [
    [0x0000, 0x001f], [0x007f, 0x009f], [0x00ad, 0x00ad], [0x061c, 0x061c], [0x180e, 0x180e],
    [0x200b, 0x200f], [0x2028, 0x2029], [0x202a, 0x202e], [0x2060, 0x2064], [0x2066, 0x206f], [0xfeff, 0xfeff], [0xfff9, 0xfffb],
  ];

  static bool hasForbiddenChar(String value) {
    for (var i = 0; i < value.length; i++) {
      final u = value.codeUnitAt(i);
      if (u >= 0xd800 && u <= 0xdbff) {
        final next = i + 1 < value.length ? value.codeUnitAt(i + 1) : -1;
        if (next < 0xdc00 || next > 0xdfff) return true;
        i++;
        continue;
      }
      if (u >= 0xdc00 && u <= 0xdfff) return true;
      if (_forbiddenUnits.any((r) => u >= r[0] && u <= r[1])) return true;
    }
    return false;
  }

  /// Sem caixa e sem acento (D-EA16).
  static String foldForComparison(String value) {
    final out = StringBuffer();
    for (final rune in value.toLowerCase().runes) {
      final ch = String.fromCharCode(rune);
      out.write(_accentFold[ch] ?? ch);
    }
    return out.toString().replaceAll(_combining, '');
  }

  /// A chave de comparação com a lista de comuns (sem caixa, sem marcas combinantes — a MESMA da API).
  static String commonListKey(String value) => value.toLowerCase().replaceAll(_combining, '');

  /// A parte local (antes do 1º `@`) do e-mail, aparada e dobrada; vazia sem `@` ou com `@` na 1ª posição.
  static String emailLocalPart(String? email) {
    if (email == null) return '';
    final at = email.indexOf('@');
    return at > 0 ? foldForComparison(email.substring(0, at).replaceAll(_edgeBlank, '')) : '';
  }

  /// Os problemas da senha NOVA (vazia = nenhum). `loginEmail` = o e-mail de login digitado/gravado na mesma tela.
  static List<String> problems(String password, {String? loginEmail, Set<String> commonSet = commonPasswords}) {
    if (isBlank(password)) return const [blank];
    final out = <String>[];
    if (hasForbiddenChar(password)) out.add(invalidChar);
    if (password.length < minLength) out.add(tooShort);
    if (password.length > maxLength) out.add(tooLong);
    // D-EA38: a lista compara a senha SEM o branco das pontas (a MESMA regra da API)
    if (commonSet.contains(commonListKey(password.replaceAll(_edgeBlank, '')))) out.add(common);
    final local = emailLocalPart(loginEmail);
    if (local.length >= emailLocalMinLength && foldForComparison(password).contains(local)) out.add(containsEmail);
    return out;
  }

  /// Chave i18n de cada problema (`forms.validation.password.*` — a fábrica traduz com `.tr()`; o texto pt é o MESMO da API).
  static String messageKey(String problem) => 'forms.validation.password.$problem';

  /// Chave i18n da regra mostrada no campo (D-EA5: "o app mostra a regra no campo").
  static const String hintKey = 'forms.validation.password.hint';

  /// Validador de formulário: vazio passa (a obrigatoriedade é do `required()`), senão a chave do 1º problema.
  static String? validate(String? value, {String? loginEmail}) {
    if (value == null || value.isEmpty) return null;
    final p = problems(value, loginEmail: loginEmail);
    return p.isEmpty ? null : messageKey(p.first);
  }
}
