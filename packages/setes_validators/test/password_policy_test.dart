// Política de senha (D-EA5/D-EA16/A-EA9 — Onda 3 do endurecer): o espelho Dart contra o VETOR de casos do setes-api
// (`setes-api/src/shared/auth/password-policy.vector.json` — o MESMO arquivo que a suíte TS lê) e a lista do app contra a da API
// (`setes-api/data/common-passwords.txt`), entrada por entrada. Pastas-irmãs (inclusive nas worktrees); `SETES_API_DIR` sobrescreve.
// Sem os arquivos a suíte FALHA ALTO (nunca "passa calada").
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:setes_validators/setes_validators.dart';
import 'package:setes_validators/src/common_passwords.g.dart';

String _apiDir() => Platform.environment['SETES_API_DIR'] ?? '../../../setes-api';

File _apiFile(String relative) {
  final file = File('${_apiDir()}/$relative');
  if (!file.existsSync()) {
    throw StateError('D-EA5: ${file.absolute.path} NÃO existe — o espelho Dart precisa do setes-api ao lado (ou SETES_API_DIR)');
  }
  return file;
}

void main() {
  final vector = jsonDecode(_apiFile('src/shared/auth/password-policy.vector.json').readAsStringSync()) as Map<String, dynamic>;
  final cases = (vector['cases'] as List).cast<Map<String, dynamic>>();
  final messages = (vector['messages'] as Map).cast<String, String>();

  group('D-EA5 — o espelho contra o vetor da API', () {
    for (final c in cases) {
      final password = c['password'] as String;
      final email = c['email'] as String?;
      test('${jsonEncode(password).substring(0, jsonEncode(password).length.clamp(0, 40))} · $email', () {
        expect(PasswordPolicy.problems(password, loginEmail: email), (c['problems'] as List).cast<String>());
      });
    }

    test('tirar caixa e acento pela tabela do vetor (D-EA16)', () {
      for (final pair in (vector['fold'] as List).cast<List>()) {
        expect(PasswordPolicy.foldForComparison(pair[0] as String), pair[1] as String);
      }
    });

    test('o texto pt de cada problema e da dica é o MESMO da API', () {
      final pt = jsonDecode(File('../../apps/web/assets/translations/pt.json').readAsStringSync()) as Map<String, dynamic>;
      final en = jsonDecode(File('../../apps/web/assets/translations/en.json').readAsStringSync()) as Map<String, dynamic>;
      final ptPassword = ((pt['forms'] as Map)['validation'] as Map)['password'] as Map;
      final enPassword = ((en['forms'] as Map)['validation'] as Map)['password'] as Map;
      for (final entry in messages.entries) {
        expect(ptPassword[entry.key], entry.value, reason: entry.key);
        expect(enPassword[entry.key], isNotNull, reason: 'en: ${entry.key}');
        expect('forms.validation.password.${entry.key}', PasswordPolicy.messageKey(entry.key));
      }
      expect(ptPassword['hint'], vector['hint']);
      expect(enPassword['hint'], isNotNull);
      expect(PasswordPolicy.hintKey, 'forms.validation.password.hint');
    });
  });

  group('A-EA9 — a lista do app é a da API', () {
    test('entrada por entrada, na mesma ordem', () {
      final api = _apiFile('data/common-passwords.txt')
          .readAsLinesSync()
          .where((l) => l.isNotEmpty && !l.startsWith('#'))
          .toList();
      expect(commonPasswords.toList(), api);
    });
  });

  group('validador de formulário', () {
    test('vazio passa (obrigatoriedade é do required); o 1º problema vira chave i18n', () {
      expect(PasswordPolicy.validate(null), isNull);
      expect(PasswordPolicy.validate(''), isNull);
      expect(PasswordPolicy.validate('abc'), 'forms.validation.password.too-short');
      expect(PasswordPolicy.validate('senha123'), 'forms.validation.password.common');
      expect(PasswordPolicy.validate('xvaldo99', loginEmail: 'valdo@x.com'), 'forms.validation.password.contains-email');
      expect(SetesValidators.password(loginEmail: () => 'valdo@x.com')('xvaldo99'), 'forms.validation.password.contains-email');
      expect(SetesValidators.password()('kq7#mv2x'), isNull);
    });
  });
}
