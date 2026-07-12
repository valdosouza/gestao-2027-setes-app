import 'mask.dart';

/// Assinatura padrão do Flutter Form (`TextFormField.validator`).
typedef SetesValidator = String? Function(String? value);

/// Validadores componíveis do setes-app (decisões 18 e 22 da Fase 2).
///
/// CONVENÇÕES (decisões 18/19 + skill internacionalizar-form.md):
/// - O retorno de erro é uma CHAVE i18n (`forms.validation.*`) — a fábrica de
///   cadastros traduz com `.tr()`. O parâmetro [message] permite override
///   manual (aceita outra chave i18n ou texto já traduzido).
/// - Exceto `required`, todo validador PASSA em valor vazio — "válido SE
///   preenchido"; obrigatoriedade é sempre explícita via `required()`.
/// - CPF/CNPJ/CEP/fone esperam somente dígitos (dados nunca gravam máscara).
/// - As regras espelham setes-api/src/shared/validation/validators.ts —
///   mudar aqui exige mudar lá.
class SetesValidators {
  const SetesValidators._();

  /// Encadeia validadores: devolve o primeiro erro encontrado.
  static SetesValidator compose(List<SetesValidator> validators) =>
      (value) {
        for (final validator in validators) {
          final error = validator(value);
          if (error != null) return error;
        }
        return null;
      };

  /// Campo não pode estar em branco.
  static SetesValidator required({String? message}) => (value) =>
      (value == null || value.trim().isEmpty)
          ? (message ?? 'forms.validation.required')
          : null;

  static SetesValidator minLength(int length, {String? message}) =>
      _ifFilled((value) => value.trim().length < length
          ? (message ?? 'forms.validation.minLength')
          : null);

  static SetesValidator maxLength(int length, {String? message}) =>
      _ifFilled((value) => value.trim().length > length
          ? (message ?? 'forms.validation.maxLength')
          : null);

  /// Somente números (sem máscara).
  static SetesValidator onlyDigits({String? message}) =>
      _ifFilled((value) => RegExp(r'^\d+$').hasMatch(value)
          ? null
          : (message ?? 'forms.validation.onlyDigits'));

  /// Somente letras (inclui acentuadas e espaço).
  static SetesValidator onlyLetters({String? message}) =>
      _ifFilled((value) => RegExp(r'^[a-zA-ZÀ-ÿ ]+$').hasMatch(value)
          ? null
          : (message ?? 'forms.validation.onlyLetters'));

  /// CPF com dígito verificador (11 dígitos, sem máscara) — SE preenchido.
  static SetesValidator cpf({String? message}) =>
      _ifFilled((value) => isValidCpf(unmask(value))
          ? null
          : (message ?? 'forms.validation.cpf'));

  /// CNPJ com dígito verificador (14 dígitos, sem máscara) — SE preenchido.
  static SetesValidator cnpj({String? message}) =>
      _ifFilled((value) => isValidCnpj(unmask(value))
          ? null
          : (message ?? 'forms.validation.cnpj'));

  /// CEP brasileiro: 8 dígitos — SE preenchido.
  static SetesValidator cep({String? message}) =>
      _ifFilled((value) => RegExp(r'^\d{8}$').hasMatch(unmask(value))
          ? null
          : (message ?? 'forms.validation.cep'));

  /// Fone brasileiro: 10 (fixo) ou 11 (celular) dígitos — SE preenchido.
  /// Máscara de digitação: `(##) #-####-####` (decisão 16).
  static SetesValidator phoneBr({String? message}) =>
      _ifFilled((value) => RegExp(r'^\d{10,11}$').hasMatch(unmask(value))
          ? null
          : (message ?? 'forms.validation.phone'));

  static SetesValidator email({String? message}) =>
      _ifFilled((value) => RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$').hasMatch(value.trim())
          ? null
          : (message ?? 'forms.validation.email'));

  /// Valor completo casa com a máscara `#`/`A` (decisão 16) — SE preenchido.
  static SetesValidator mask(String mask, {String? message}) =>
      _ifFilled((value) => matchesMask(mask, value)
          ? null
          : (message ?? 'forms.validation.mask'));

  /// "Válido SE preenchido": vazio passa (obrigatoriedade é do required()).
  static SetesValidator _ifFilled(String? Function(String value) check) =>
      (value) {
        if (value == null || value.trim().isEmpty) return null;
        return check(value);
      };

  // -------------------------------------------------------------------
  // Funções puras (mesmos algoritmos do validators.ts da API)
  // -------------------------------------------------------------------

  /// Dígito verificador de CPF (módulo 11). Espera 11 dígitos sem máscara.
  static bool isValidCpf(String cpf) {
    if (!RegExp(r'^\d{11}$').hasMatch(cpf)) return false;
    if (RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) return false;

    final digits = cpf.split('').map(int.parse).toList();
    for (final position in [9, 10]) {
      var sum = 0;
      for (var i = 0; i < position; i++) {
        sum += digits[i] * (position + 1 - i);
      }
      final check = ((sum * 10) % 11) % 10;
      if (check != digits[position]) return false;
    }
    return true;
  }

  /// Dígito verificador de CNPJ (pesos 2..9). Espera 14 dígitos sem máscara.
  static bool isValidCnpj(String cnpj) {
    if (!RegExp(r'^\d{14}$').hasMatch(cnpj)) return false;
    if (RegExp(r'^(\d)\1{13}$').hasMatch(cnpj)) return false;

    final digits = cnpj.split('').map(int.parse).toList();
    for (final position in [12, 13]) {
      var weight = position - 7;
      var sum = 0;
      for (var i = 0; i < position; i++) {
        sum += digits[i] * weight;
        weight = weight == 2 ? 9 : weight - 1;
      }
      final rest = sum % 11;
      final check = rest < 2 ? 0 : 11 - rest;
      if (check != digits[position]) return false;
    }
    return true;
  }
}
