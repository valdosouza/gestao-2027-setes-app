// Espelho dos testes de setes-api/src/__tests__/validators.test.ts —
// as regras precisam ser IDÊNTICAS nos dois lados (decisão 18 da Fase 2).
import 'package:flutter_test/flutter_test.dart';
import 'package:setes_validators/setes_validators.dart';

void main() {
  group('isValidCpf', () {
    test('aceita CPFs válidos', () {
      expect(SetesValidators.isValidCpf('52998224725'), isTrue);
      expect(SetesValidators.isValidCpf('11144477735'), isTrue);
    });
    test('rejeita dígito errado, repetidos, máscara e vazio', () {
      expect(SetesValidators.isValidCpf('52998224724'), isFalse);
      expect(SetesValidators.isValidCpf('11111111111'), isFalse);
      expect(SetesValidators.isValidCpf('529.982.247-25'), isFalse);
      expect(SetesValidators.isValidCpf(''), isFalse);
    });
  });

  group('isValidCnpj', () {
    test('aceita CNPJs válidos', () {
      expect(SetesValidators.isValidCnpj('11222333000181'), isTrue);
      expect(SetesValidators.isValidCnpj('11444777000161'), isTrue);
    });
    test('rejeita dígito errado e repetidos', () {
      expect(SetesValidators.isValidCnpj('11222333000180'), isFalse);
      expect(SetesValidators.isValidCnpj('00000000000000'), isFalse);
      expect(SetesValidators.isValidCnpj('12345678000199'), isFalse);
    });
  });

  group('validadores componíveis', () {
    test('required acusa vazio; demais passam em vazio (válido SE preenchido)', () {
      expect(SetesValidators.required()(''), 'forms.validation.required');
      expect(SetesValidators.required()('x'), isNull);
      expect(SetesValidators.cpf()(''), isNull);
      expect(SetesValidators.cpf()(null), isNull);
      expect(SetesValidators.minLength(3)(''), isNull);
    });
    test('override manual de mensagem (campo + mensagem informados na tela)', () {
      expect(SetesValidators.cpf(message: 'forms.customer.cpfInvalido')('123'),
          'forms.customer.cpfInvalido');
    });
    test('compose devolve o primeiro erro', () {
      final validator = SetesValidators.compose([
        SetesValidators.required(),
        SetesValidators.minLength(3),
      ]);
      expect(validator(''), 'forms.validation.required');
      expect(validator('ab'), 'forms.validation.minLength');
      expect(validator('abc'), isNull);
    });
    test('cpf aceita valor mascarado na digitação (unmask antes de validar)', () {
      expect(SetesValidators.cpf()('529.982.247-25'), isNull);
    });
    test('onlyDigits/onlyLetters', () {
      expect(SetesValidators.onlyDigits()('123'), isNull);
      expect(SetesValidators.onlyDigits()('12a'), 'forms.validation.onlyDigits');
      expect(SetesValidators.onlyLetters()('São Paulo'), isNull);
      expect(SetesValidators.onlyLetters()('SP1'), 'forms.validation.onlyLetters');
    });
    test('phoneBr e cep', () {
      expect(SetesValidators.phoneBr()('31988887777'), isNull);
      expect(SetesValidators.phoneBr()('(31) 9-8888-7777'), isNull);
      expect(SetesValidators.phoneBr()('123'), 'forms.validation.phone');
      expect(SetesValidators.cep()('30130010'), isNull);
      expect(SetesValidators.cep()('301300'), 'forms.validation.cep');
    });
  });

  group('máscara #/A (decisão 16)', () {
    test('matchesMask', () {
      expect(matchesMask('(##) #-####-####', '(31) 9-8888-7777'), isTrue);
      expect(matchesMask('(##) #-####-####', '(31) A-8888-7777'), isFalse);
      expect(matchesMask('AAA-####', 'ABC-1234'), isTrue);
      expect(matchesMask('', 'qualquer'), isTrue);
    });
    test('unmask remove só os literais (dados nunca gravam máscara — decisão 19)', () {
      expect(unmask('(31) 9-8888-7777'), '31988887777');
      expect(unmask('ABC-1234'), 'ABC1234');
    });
    test('SetesMaskFormatter guia a digitação inserindo literais', () {
      final formatter = SetesMaskFormatter('(##) #-####-####');
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '31988887777'),
      );
      expect(result.text, '(31) 9-8888-7777');
    });
    test('SetesMaskFormatter descarta caractere inválido para a posição', () {
      final formatter = SetesMaskFormatter('####');
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '12a3'),
      );
      expect(result.text, '123');
    });
  });
}
