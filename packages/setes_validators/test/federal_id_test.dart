// Inscrição federal (D-CJ2 — frente do CNPJ alfanumérico, 2026-10-15): o espelho Dart contra o VETOR OFICIAL de casos — o MESMO
// arquivo que a suíte TS do núcleo lê (`fiscal-api/src/federal-id/federal-id.vector.json`). O espelho é garantido por construção, não
// por cópia. O caminho segue a simetria do workspace (pastas-irmãs, inclusive nas worktrees); `FISCAL_API_DIR` sobrescreve. Sem o
// arquivo a suíte FALHA ALTO (nunca "passa calada").
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setes_validators/setes_validators.dart';

Map<String, dynamic> _vector() {
  final base = Platform.environment['FISCAL_API_DIR'] ?? '../../../fiscal-api';
  final file = File('$base/src/federal-id/federal-id.vector.json');
  if (!file.existsSync()) {
    throw StateError('D-CJ2: o vetor oficial ${file.absolute.path} NÃO existe — o espelho Dart precisa do fiscal-api ao lado '
        '(ou FISCAL_API_DIR apontando para ele)');
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  final v = _vector();
  List<Map<String, dynamic>> list(String k) => (v[k] as List).cast<Map<String, dynamic>>();

  group('D-CJ2 — o espelho Dart contra o vetor oficial', () {
    for (final c in list('cnpjValidos')) {
      test('CNPJ válido ${c['valor']} (${c['origem']})', () {
        expect(FederalIdRules.isValidCnpj(c['valor'] as String), isTrue);
        expect(FederalId.of(FederalIdKind.cnpj, c['valor'] as String)?.value, c['valor']);
      });
    }
    for (final c in list('cnpjInvalidos')) {
      test('CNPJ inválido "${c['valor']}" (${c['motivo']})', () {
        expect(FederalIdRules.isValidCnpj(c['valor'] as String), isFalse);
        expect(FederalId.of(FederalIdKind.cnpj, c['valor'] as String), isNull);
      });
    }
    for (final c in list('normalizarCnpj')) {
      test('normalizar "${c['entrada']}" → ${c['saida']}', () {
        expect(FederalIdRules.normalizeCnpj(c['entrada'] as String), c['saida']);
      });
    }
    for (final c in list('canonicalizarTexto')) {
      test('canonicalizar "${c['entrada']}" → ${c['saida']}', () {
        expect(FederalIdRules.canonicalizeText(c['entrada'] as String), c['saida']);
      });
    }
    for (final c in list('formatarCnpj')) {
      test('formatar ${c['valor']} → ${c['saida']}', () {
        expect(FederalIdRules.formatCnpj(c['valor'] as String), c['saida']);
      });
    }
    for (final c in list('dvCnpj')) {
      test('DV de ${c['base']} = ${c['dv']}', () {
        expect(FederalIdRules.cnpjCheckDigits(c['base'] as String), c['dv']);
      });
    }
    test('CPF segue numérico', () {
      for (final c in (v['cpfValidos'] as List).cast<String>()) {
        expect(FederalIdRules.isValidCpf(c), isTrue, reason: c);
      }
      for (final c in (v['cpfInvalidos'] as List).cast<String>()) {
        expect(FederalIdRules.isValidCpf(c), isFalse, reason: c);
      }
      for (final c in list('formatarCpf')) {
        expect(FederalIdRules.formatCpf(c['valor'] as String), c['saida']);
      }
    });
  });

  group('D-CJ2 — o que a peça promete além do vetor', () {
    test('mod11 recusa o que não é [0-9A-Z]', () {
      expect(() => FederalIdRules.mod11Ascii48('12abc'), throwsArgumentError);
      expect(FederalIdRules.cnpjCheckDigits('12abc34501de'), isNull);
    });
    test('o tipo vem de quem chama (o LUGAR) — nunca do comprimento', () {
      expect(FederalId.of(FederalIdKind.cnpj, '52998224725'), isNull);
      expect(FederalId.of(FederalIdKind.cpf, '11222333000181'), isNull);
      expect(FederalId.of(FederalIdKind.cnpj, 'PC3D315K000193').toString(), 'PC.3D3.15K/0001-93');
    });
    test('SetesValidators.isValidCnpj/isValidCpf = a mesma regra (a superfície antiga delega)', () {
      expect(SetesValidators.isValidCnpj('12ABC34501DE35'), isTrue);
      expect(SetesValidators.isValidCnpj('12abc34501de35'), isFalse);
      expect(SetesValidators.isValidCpf('52998224725'), isTrue);
    });
  });

  // D-CJ8 (onda 1): a digitação guiada do CNPJ alfanumérico nos 5 formulários de entidade
  group('CnpjInputFormatter', () {
    String typed(String text) => const CnpjInputFormatter()
        .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text))
        .text;
    test('insere os literais nas posições do CNPJ numérico e sobe a minúscula', () {
      expect(typed('pc3d315k000193'), 'PC.3D3.15K/0001-93');
      expect(typed('12345678000195'), '12.345.678/0001-95');
      expect(typed('12abc'), '12.ABC');
      expect(typed('12'), '12');
    });
    test('colar com máscara dá o mesmo; o resultado canonicalizado é a forma válida', () {
      expect(typed('12.ABC.345/01DE-35'), '12.ABC.345/01DE-35');
      expect(FederalIdRules.canonicalizeText(typed('12.abc.345/01de-35')), '12ABC34501DE35');
    });
    test('DV só aceita dígito; caractere fora de [0-9A-Za-z] não entra; para em 14 posições', () {
      expect(typed('12ABC34501DEX35'), '12.ABC.345/01DE-35');
      expect(typed('12ÁBC'), '12.BC');
      expect(typed('12ABC34501DE359999'), '12.ABC.345/01DE-35');
    });
    test('o cursor vai para o fim (como o SetesMaskFormatter)', () {
      final v = const CnpjInputFormatter().formatEditUpdate(TextEditingValue.empty, const TextEditingValue(text: 'pc3d'));
      expect(v.selection.baseOffset, v.text.length);
    });
  });
}
