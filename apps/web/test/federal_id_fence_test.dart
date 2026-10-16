// CERCA da inscrição federal no app (D-CJ12 = Q-CJ12, frente do CNPJ alfanumérico, Valdo 2026-10-15 — gêmea das cercas TS do setes-api,
// fiscal-api e nfse-api): "tirar o que não é dígito" (ou "tirar as letras") NUNCA sobre inscrição federal — aplicado a um CNPJ alfanumérico
// dá OUTRO número (ou um "CPF"). A regra é `FederalIdRules` (setes_validators — espelho da peça do núcleo): canonicaliza, nunca apaga.
// Gate adversarial da onda 0 (LOW): a 1ª versão lia LINHA a LINHA só `RegExp(r'\D')`/`[^0-9]`/`[^\d]` — escapavam RegExp sem raw, o
// argumento na linha de baixo (o dart format faz isso), classe negada com 1 caractere a mais, `[A-Z]` (tira as letras), o filtro por
// '0123456789' e o `allMatches` de `\d`. Agora o arquivo INTEIRO: todo `RegExp(` + texto (raw ou não, quebra de linha permitida), decodificado,
// contra (1) `\D` ou classe negada com 0-9/\d/0123456789, (2) classe só de dígitos, (3) classe só de letras; e (4) `'0123456789'.contains`.
// Lista BRANCA = `arquivo: padrão ×N ocorrências` com o MOTIVO; alarme novo (ou contagem diferente) quebra; entrada que SUMIU também quebra.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _regexpCall = RegExp(r'''RegExp\(\s*(r?)('|")((?:(?!\2).)*)\2''', dotAll: true);
final _notDigit = RegExp(r'\\D|\[\^[^\]]*(?:0-9|\\d|0123456789)[^\]]*\]');
final _digitsOnly = RegExp(r'^(?:\\d|\[0-9\])[+*]?$');
final _lettersOnly = RegExp(r'^\[(?:A-Z|a-z|A-Za-z|a-zA-Z)\][+*]?$');
final _digitFilter = RegExp(r'''['"]0123456789['"]\s*\.\s*contains''');

/// Os alarmes de um código-fonte: `padrão` por ocorrência (o padrão é o texto DECODIFICADO da regex).
List<String> strippingHitsIn(String code) {
  final hits = <String>[];
  for (final m in _regexpCall.allMatches(code)) {
    final raw = m.group(1) == 'r';
    var pattern = m.group(3)!;
    if (!raw) pattern = pattern.replaceAll(r'\\', r'\');       // string não-raw: o fonte tem a barra escapada
    if (_notDigit.hasMatch(pattern) || _digitsOnly.hasMatch(pattern) || _lettersOnly.hasMatch(pattern)) {
      hits.add("RegExp(r'$pattern')");
    }
  }
  for (final _ in _digitFilter.allMatches(code)) {
    hits.add("'0123456789'.contains");
  }
  return hits;
}

/// `arquivo: padrão ×N` (N = ocorrências no arquivo) → motivo.
const _allowed = <String, String>{
  r"lib/app/shared/entity/domain/object_entity_fiscal.dart: RegExp(r'\D') ×2":
      'cpfDigits (CPF segue numérico) e cnpjDigits — o do CNPJ VENCE NA ONDA 1 (S2 do inventário: o objeto guarda e envia a forma canônica)',
  r"lib/app/shared/entity/widgets/entity_main_tab.dart: RegExp(r'\D') ×2":
      'validação do CPF (ok) e do CNPJ do formulário — a do CNPJ VENCE NA ONDA 1 (D-CJ8: o campo passa a usar FederalIdRules)',
  r"packages/setes_validators/lib/src/mask.dart: RegExp(r'[^0-9a-zA-ZÀ-ÿ]') ×1":
      'unmask do motor de máscara configurável: tira só os LITERAIS (mantém letras — B6); CPF/CNPJ saem do motor (D-CJ11)',
  r"packages/setes_validators/lib/src/mask.dart: RegExp(r'\d') ×2":
      'motor de máscara configurável: confere UM caractere na posição `#` (hasMatch, não coleta) — matchesMask e SetesMaskFormatter (B4/B5); '
          'nenhum CPF/CNPJ passa pelo motor (catálogo sem campo de inscrição — anexo §8.1; D-CJ11)',
};

Iterable<File> _dartFiles(String dir) => Directory(dir).existsSync()
    ? Directory(dir).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))
    : const <File>[];

/// Comentário de linha não conta (mantém a quebra para o resto da varredura).
String _uncomment(String src) => src.split('\n').map((l) => l.replaceFirst(RegExp(r'^\s*//.*$'), '')).join('\n');

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
    ]) {
      expect([code, strippingHitsIn(code).isNotEmpty], [code, isTrue]);
    }
    for (final code in <String>[
      r"x.replaceAll(RegExp(r'[./\- ]'), '')",
      r"RegExp(r'^[0-9A-Z]{12}[0-9]{2}$').hasMatch(x)",
      r"RegExp(r'^\d{8}$').hasMatch(x)",
    ]) {
      expect([code, strippingHitsIn(code)], [code, isEmpty]);
    }
  });
}
