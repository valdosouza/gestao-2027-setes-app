// Contrato do envelope de erro `{ error, code?, ref?, fields[] }` no
// pacote core: `fields[].expected` (D-N3 da negociação do pedido,
// 2026-09-07) — valor ESPERADO nos erros de conferência numérica, para a
// tela corrigir com o número em vez de fazer parse da prosa.

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FailureField.expected', () {
    test('lê expected inteiro ou decimal; ausente = null', () {
      expect(
        FailureField.fromJson({
          'field': 'installments',
          'message': 'Parcelamento 100 difere do valor atual da ordem 1250',
          'expected': 1250,
        }).expected,
        1250.0,
      );
      expect(
        FailureField.fromJson({
          'field': 'checks.1',
          'message': 'Soma dos cheques 40 difere do valor da parcela 45.5',
          'expected': 45.5,
        }).expected,
        45.5,
      );
      expect(
        FailureField.fromJson({'field': 'deadline', 'message': 'inválido'})
            .expected,
        isNull,
      );
    });

    test('expected entra na igualdade (Equatable)', () {
      const a = FailureField(field: 'f', message: 'm', expected: 1);
      const b = FailureField(field: 'f', message: 'm', expected: 2);
      const c = FailureField(field: 'f', message: 'm', expected: 1);
      expect(a, c);
      expect(a == b, isFalse);
    });
  });

  test('Failure.fieldExpected busca pelo campo apontado', () {
    const failure = Failure(
      message: 'Valor do parcelamento não confere com o valor da ordem',
      statusCode: 422,
      code: 'INSTALLMENT_MISMATCH',
      fields: [
        FailureField(field: 'installments', message: 'x', expected: 100),
      ],
    );
    expect(failure.fieldExpected('installments'), 100);
    expect(failure.fieldExpected('deadline'), isNull);
    expect(failure.fieldMessage('installments'), 'x');
  });
}
