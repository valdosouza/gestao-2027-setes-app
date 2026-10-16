// D-CJ3 (frente do CNPJ alfanumérico, onda 1 — 2026-10-16): o `expected` do envelope de erro passa a poder ser TEXTO (a forma canônica
// esperada de uma inscrição federal). Aditivo à D-N3: o número segue em `expected`; o texto vai para `expectedText`; nenhum dos dois
// derruba o parse (antes `as num?` lançava com texto).
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('expected numérico (D-N3) segue em `expected`', () {
    final f = FailureField.fromJson({'field': 'parcels', 'message': 'm', 'expected': 3});
    expect([f.expected, f.expectedText], [3.0, null]);
  });
  test('expected TEXTO (D-CJ3) vai para `expectedText`, sem lançar', () {
    final f = FailureField.fromJson({'field': 'company.cnpj', 'message': 'CNPJ fora da forma canônica', 'expected': '12ABC34501DE35'});
    expect([f.expected, f.expectedText], [null, '12ABC34501DE35']);
  });
  test('ausente ou de outro tipo → os dois null', () {
    for (final e in <Object?>[null, true, <String>['x'], {'a': 1}]) {
      final f = FailureField.fromJson({'field': 'x', 'message': 'm', 'expected': e});
      expect([f.expected, f.expectedText], [null, null], reason: '$e');
    }
  });
}
