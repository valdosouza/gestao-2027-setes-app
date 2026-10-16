// CERCA da inscrição federal no app (D-CJ12 = Q-CJ12, frente do CNPJ alfanumérico, Valdo 2026-10-15 — gêmea das cercas TS do setes-api,
// fiscal-api e nfse-api): "tirar o que não é dígito" (ou "tirar as letras") NUNCA sobre inscrição federal — aplicado a um CNPJ alfanumérico
// dá OUTRO número (ou um "CPF"). A regra é `FederalIdRules` (setes_validators — espelho da peça do núcleo): canonicaliza, nunca apaga.
// Gate adversarial da onda 0 (LOW): a 1ª versão lia LINHA a LINHA só `RegExp(r'\D')`/`[^0-9]`/`[^\d]` — escapavam RegExp sem raw, o
// argumento na linha de baixo (o dart format faz isso), classe negada com 1 caractere a mais, `[A-Z]` (tira as letras), o filtro por
// '0123456789' e o `allMatches` de `\d`. Agora o arquivo INTEIRO: todo `RegExp(` + texto (raw ou não, quebra de linha permitida), decodificado,
// contra (1) `\D` ou classe negada com 0-9/\d/0123456789, (2) classe só de dígitos, (3) classe só de letras; e (4) `'0123456789'.contains`.
// Lista BRANCA = `arquivo: padrão ×N ocorrências` com o MOTIVO; alarme novo (ou contagem diferente) quebra; entrada que SUMIU também quebra.
// Gate adversarial da onda 1 (LOW, 2026-10-16): escapavam as formas EQUIVALENTES — faixa de código (`c >= 48 && c <= 57`), `\p{L}`/`\p{N}`,
// hex (`[^\x30-\x39]`), o padrão guardado numa variável (`final p = r'\D'; RegExp(p)`) e a conversão numérica (`int.parse`/`int.tryParse`)
// sobre a inscrição (a "regra 5" das cercas TS). Agora: (5) o padrão em variável é RESOLVIDO pela atribuição literal no mesmo arquivo; (6) a
// faixa de código de dígito/letra é alarme; (7) `int|num|double.parse/tryParse` e o helper "só dígitos" num comando que fala de inscrição.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _regexpCall = RegExp(r'''RegExp\(\s*(r?)('|")((?:(?!\2).)*)\2''', dotAll: true);
final _regexpVarCall = RegExp(r'RegExp\(\s*([A-Za-z_]\w*)\s*[,)]');
final _stringConst = RegExp(r'''\b([A-Za-z_]\w*)\s*=\s*(r?)('|")((?:(?!\3).)*)\3\s*;''');
final _notDigit = RegExp(r'\\D|\\P\{N|\[\^[^\]]*(?:0-9|\\d|0123456789|\\x3[0-9]|\\u003[0-9]|\\p\{N)[^\]]*\]');
final _digitsOnly = RegExp(r'^(?:\\d|\\p\{N\w*\}|\[(?:0-9|\\d|\\x30-\\x39|\\p\{N\w*\})\])[+*]?$');
final _lettersOnly = RegExp(r'^(?:\\p\{L\w*\}|\[(?:A-Z|a-z|A-Za-z|a-zA-Z|\\p\{L\w*\})\])[+*]?$');
final _digitFilter = RegExp(r'''['"]0123456789['"]\s*\.\s*contains''');

/// Faixas de CÓDIGO de caractere (`c >= 48 && c <= 57`, nos dois sentidos, decimal ou hex) — rótulo → regex.
final _codeRanges = <String, RegExp>{
  'faixa de código 0–9': _range('48|0x30', '57|0x39'),
  'faixa de código A–Z': _range('65|0x41', '90|0x5[aA]'),
  'faixa de código a–z': _range('97|0x61', '122|0x7[aA]'),
};
RegExp _range(String lo, String hi) => RegExp('(?:>=\\s*(?:$lo)\\b[^;]{0,60}?<=\\s*(?:$hi)\\b)'
    '|(?:<=\\s*(?:$hi)\\b[^;]{0,60}?>=\\s*(?:$lo)\\b)'
    '|(?:<\\s*(?:$lo)\\b[^;]{0,60}?>\\s*(?:$hi)\\b)');

final _numericParse = RegExp(r'\b(?:int|num|double)\.(?:try)?[pP]arse\b');
final _digitHelperCall = RegExp(r'\b(_?[A-Za-z]\w*)\s*\(');
final _digitHelperName = RegExp(r'digits|numeros|onlynum|sonum', caseSensitive: false);   // 'digits': "digital" não é helper
final _inscriptionText = RegExp(r'cnpj|cpf|inscri|\binsc\b|federal|\bni\b', caseSensitive: false);

bool _isStrippingPattern(String pattern) =>
    _notDigit.hasMatch(pattern) || _digitsOnly.hasMatch(pattern) || _lettersOnly.hasMatch(pattern);

String _decoded(bool raw, String text) => raw ? text : text.replaceAll(r'\\', r'\');   // não-raw: o fonte tem a barra escapada

/// O COMANDO em volta de [at]: do último `;`/`{`/`}` antes até o próximo `;`.
String _statementAt(String code, int at) {
  var start = 0;
  for (final ch in [';', '{', '}']) {
    final i = code.lastIndexOf(ch, at);
    if (i + 1 > start) start = i + 1;
  }
  final end = code.indexOf(';', at);
  return code.substring(start, end < 0 ? code.length : end);
}

/// Os alarmes de um código-fonte: `padrão` por ocorrência (o padrão é o texto DECODIFICADO da regex).
List<String> strippingHitsIn(String code) {
  final hits = <String>[];
  for (final m in _regexpCall.allMatches(code)) {
    final pattern = _decoded(m.group(1) == 'r', m.group(3)!);
    if (_isStrippingPattern(pattern)) hits.add("RegExp(r'$pattern')");
  }
  // (5) o padrão numa variável: resolvido pela atribuição LITERAL do mesmo arquivo
  final consts = <String, String>{
    for (final c in _stringConst.allMatches(code)) c.group(1)!: _decoded(c.group(2) == 'r', c.group(4)!),
  };
  for (final m in _regexpVarCall.allMatches(code)) {
    final pattern = consts[m.group(1)];
    if (pattern != null && _isStrippingPattern(pattern)) hits.add("RegExp(${m.group(1)} = r'$pattern')");
  }
  for (final _ in _digitFilter.allMatches(code)) {
    hits.add("'0123456789'.contains");
  }
  // (6) faixa de código de dígito/letra
  _codeRanges.forEach((label, re) {
    for (final _ in re.allMatches(code)) {
      hits.add(label);
    }
  });
  // (7) conversão numérica ou helper "só dígitos" num comando que fala de inscrição
  for (final m in _numericParse.allMatches(code)) {
    if (_inscriptionText.hasMatch(_statementAt(code, m.start))) hits.add('${m.group(0)} sobre inscrição');
  }
  for (final m in _digitHelperCall.allMatches(code)) {
    final name = m.group(1)!;
    if (!_digitHelperName.hasMatch(name) || name.toLowerCase().contains('checkdigit')) continue;
    if (_inscriptionText.hasMatch(_statementAt(code, m.start))) hits.add('$name(…) sobre inscrição');
  }
  return hits;
}

/// `arquivo: padrão ×N` (N = ocorrências no arquivo) → motivo.
const _allowed = <String, String>{
  // onda 1 (D-CJ8, 2026-10-16): o `cnpjDigits`/`cpfDigits` e a validação do formulário de entidade SAÍRAM daqui — o objeto guarda e envia
  // a forma canônica (`cnpjCanonical`) e a marca inline + as pendências usam `cnpjProblem`/`cpfProblem` (FederalIdRules)
  r"packages/setes_validators/lib/src/mask.dart: RegExp(r'[^0-9a-zA-ZÀ-ÿ]') ×1":
      'unmask do motor de máscara configurável: tira só os LITERAIS (mantém letras — B6); CPF/CNPJ saem do motor (D-CJ11)',
  r"packages/setes_validators/lib/src/mask.dart: RegExp(r'\d') ×2":
      'motor de máscara configurável: confere UM caractere na posição `#` (hasMatch, não coleta) — matchesMask e SetesMaskFormatter (B4/B5); '
          'nenhum CPF/CNPJ passa pelo motor (catálogo sem campo de inscrição — anexo §8.1; D-CJ11)',
  // gate da onda 1 (2026-10-16): as faixas de código entraram na cerca — as três do `CnpjInputFormatter` são CLASSIFICAÇÃO, não filtro
  'packages/setes_validators/lib/src/federal_id.dart: faixa de código 0–9 ×1':
      'CnpjInputFormatter._isDigit: classifica cada caractere da edição; o que não é dígito/letra/literal RECUSA a edição inteira (nunca '
          'apaga — D-CJ2) e decide que o DV só aceita dígito',
  'packages/setes_validators/lib/src/federal_id.dart: faixa de código A–Z ×1':
      'CnpjInputFormatter._isUpper: classifica (letra maiúscula entra como está) — nada é descartado',
  'packages/setes_validators/lib/src/federal_id.dart: faixa de código a–z ×1':
      'CnpjInputFormatter._isLower: classifica (minúscula ASCII sobe para A–Z) — nada é descartado',
};

Iterable<File> _dartFiles(String dir) => Directory(dir).existsSync()
    ? Directory(dir).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))
    : const <File>[];

/// Comentário de linha não conta (mantém a quebra para o resto da varredura). Sem `$` no fim: o `.` do Dart não casa o `\r` — com `.*$`
/// o comentário de um arquivo CRLF nunca saía (achado ao endurecer a cerca no gate da onda 1).
String _uncomment(String src) => src.split('\n').map((l) => l.replaceFirst(RegExp(r'^\s*//.*'), '')).join('\n');

void main() {
  final hits = <String>[];
  final roots = ['lib', ...Directory('../../packages').listSync().whereType<Directory>().map((d) => '${d.path}/lib')];
  for (final root in roots) {
    for (final f in _dartFiles(root)) {
      final counts = <String, int>{};
      for (final h in strippingHitsIn(_uncomment(f.readAsStringSync()))) {
        counts[h] = (counts[h] ?? 0) + 1;
      }
      final rel = f.path.replaceAll(r'\', '/').replaceFirst(RegExp(r'^\.\./\.\./'), '');
      counts.forEach((h, n) => hits.add('$rel: $h ×$n'));
    }
  }

  test('D-CJ12 — todo "tirar o que não é dígito / as letras" do app está na lista branca (com o motivo e a contagem)', () {
    expect(hits.where((h) => !_allowed.containsKey(h)).toList(), isEmpty);
  });
  test('D-CJ12 — a lista branca não apodrece', () {
    expect(_allowed.keys.where((k) => !hits.contains(k)).toList(), isEmpty);
  });
  test('D-CJ12 — a cerca enxerga o que deve (sonda — inclui as 6 formas que escapavam da 1ª versão)', () {
    for (final code in <String>[
      r"x.replaceAll(RegExp(r'\D'), '')",
      r"x.replaceAll(RegExp(r'[^0-9]'), '')",
      r'x.replaceAll(RegExp(r"[^\d]"), "")',
      r"x.replaceAll(RegExp('\\D'), '')",                       // string NÃO-raw: o fonte tem duas barras
      "x.replaceAll(RegExp(\n    r'\\D'), '')",                  // argumento na linha de baixo (dart format)
      r"x.replaceAll(RegExp(r'[^0-9.]'), '')",                  // classe negada com um caractere a mais
      r"x.replaceAll(RegExp(r'[A-Z]'), '')",                    // tira as LETRAS
      r"x.split('').where((c) => '0123456789'.contains(c)).join()",
      r"RegExp(r'\d').allMatches(x).map((m) => m[0]).join()",
      // gate da onda 1: as formas equivalentes
      r'String.fromCharCodes(cnpj.codeUnits.where((c) => c >= 48 && c <= 57))',
      r'String.fromCharCodes(cnpj.codeUnits.where((c) => c < 0x30 || c > 0x39))',
      r"cnpj.replaceAll(RegExp(r'\p{L}', unicode: true), '')",
      r"cnpj.replaceAll(RegExp(r'\P{N}', unicode: true), '')",
      r"cnpj.replaceAll(RegExp(r'[^\x30-\x39]'), '')",
      r"final p = r'\D'; cnpj.replaceAll(RegExp(p), '')",
      r"cnpj.split('').where((c) => int.tryParse(c) != null).join()",
      r'int.parse(cnpj).toString().padLeft(14, "0")',
      r'final doc = onlyDigits(company.cnpj);',
    ]) {
      expect([code, strippingHitsIn(code).isNotEmpty], [code, isTrue]);
    }
    for (final code in <String>[
      r"x.replaceAll(RegExp(r'[./\- ]'), '')",
      r"RegExp(r'^[0-9A-Z]{12}[0-9]{2}$').hasMatch(x)",
      r"RegExp(r'^\d{8}$').hasMatch(x)",
      r"RegExp(r'^\p{L}+$', unicode: true).hasMatch(name)",
      r'final id = int.parse(orderId);',
      r'FederalIdRules.cnpjCheckDigits(base12)',
      r"final p = r'[./\- ]'; cnpj.replaceAll(RegExp(p), '')",
    ]) {
      expect([code, strippingHitsIn(code)], [code, isEmpty]);
    }
  });
}
