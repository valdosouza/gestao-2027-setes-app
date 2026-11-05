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
  };

  /// Sem caixa e sem acento (D-EA16).
  static String foldForComparison(String value) {
    final out = StringBuffer();
    for (final rune in value.toLowerCase().runes) {
      final ch = String.fromCharCode(rune);
      out.write(_accentFold[ch] ?? ch);
    }
    return out.toString();
  }

  /// A parte local (antes do 1º `@`) do e-mail, aparada e dobrada; vazia sem `@` ou com `@` na 1ª posição.
  static String emailLocalPart(String? email) {
    if (email == null) return '';
    final at = email.indexOf('@');
    return at > 0 ? foldForComparison(email.substring(0, at).trim()) : '';
  }

  /// Os problemas da senha NOVA (vazia = nenhum). `loginEmail` = o e-mail de login digitado/gravado na mesma tela.
  static List<String> problems(String password, {String? loginEmail, Set<String> commonSet = commonPasswords}) {
    if (password.trim().isEmpty) return const [blank];
    final out = <String>[];
    if (password.length < minLength) out.add(tooShort);
    if (password.length > maxLength) out.add(tooLong);
    if (commonSet.contains(password.toLowerCase())) out.add(common);
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
