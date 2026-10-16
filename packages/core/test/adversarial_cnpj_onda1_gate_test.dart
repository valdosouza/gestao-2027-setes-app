// GATE ADVERSARIAL da ONDA 1 da frente do CNPJ alfanumérico (skill `testar-adversarial.md`, 2026-10-16) — `FailureField.fromJson`
// com `expected` de tipos variados (D-CJ3: texto na inscrição federal × número da D-N3). Ataque que RESISTIU = teste verde.
import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FailureField parse(Object? e) => FailureField.fromJson({'field': 'f', 'message': 'm', 'expected': e});

  test('número de qualquer forma (int, double, negativo, zero, enorme) → `expected` double; `expectedText` null', () {
    for (final e in <num>[3, 2.5, -1, 0, 1e308, 9007199254740993]) {
      final f = parse(e);
      expect([e, f.expected, f.expectedText], [e, e.toDouble(), null]);
    }
  });
  test('texto (inclusive vazio, numérico e com letras) → `expectedText`; NUNCA coagido para número (o consumidor da D-N3 não recebe "3")', () {
    for (final e in ['12ABC34501DE35', '', '3', '3.5', ' 12ABC34501DE35 ']) {
      final f = parse(e);
      expect([e, f.expected, f.expectedText], [e, null, e]);
    }
  });
  test('tipos estranhos (bool, lista, mapa, null, ausente) → os dois null, sem lançar', () {
    for (final e in <Object?>[true, false, <Object>[], <Object>['x'], <String, Object>{'a': 1}, null]) {
      final f = parse(e);
      expect([f.expected, f.expectedText], [null, null], reason: '$e');
    }
    final f = FailureField.fromJson({'field': 'f', 'message': 'm'});
    expect([f.expected, f.expectedText], [null, null]);
  });
  test('envelope REAL do setes-api (JSON) com expected texto e número no mesmo erro', () {
    final body = jsonDecode('{"error":"Validação falhou","code":"VALIDATION_FAILED","fields":['
        '{"field":"company.cnpj","message":"CNPJ fora da forma canônica","expected":"12ABC34501DE35"},'
        '{"field":"parcels","message":"x","expected":3}]}') as Map<String, dynamic>;
    final fields = (body['fields'] as List).whereType<Map<String, dynamic>>().map(FailureField.fromJson).toList();
    final failure = Failure(message: body['error'] as String, statusCode: 400, fields: fields);
    expect(failure.fieldExpected('company.cnpj'), isNull);      // o leitor NUMÉRICO não é enganado pelo texto
    expect(failure.fieldExpected('parcels'), 3.0);
    expect(fields.first.expectedText, '12ABC34501DE35');
  });
  test('igualdade (Equatable) distingue o expected TEXTO', () {
    expect(parse('A'), parse('A'));
    expect(parse('A') == parse('B'), isFalse);
    expect(parse(3) == parse('3'), isFalse);
  });
}
