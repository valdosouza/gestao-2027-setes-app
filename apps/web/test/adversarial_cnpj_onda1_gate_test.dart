// GATE ADVERSARIAL da ONDA 1 da frente do CNPJ alfanumérico (skill `testar-adversarial.md`, 2026-10-16) — o julgamento ÚNICO do
// formulário de entidade (`cnpjProblem`/`cpfProblem`) × a decisão da API, e o objeto de domínio que ENVIA (`toJson`).
// A API (setes-api `fiscal.dto.ts`) aceita só a forma canônica; o app canonicaliza ANTES de julgar e envia a canônica. Então a promessa
// "mesma decisão" é: o app diz OK  ⇔  a API aceita o que o app ENVIA  ⇔  a forma canônica do texto é válida (o `expected` da API).
// Ataque que RESISTIU = teste verde. Achado CONFIRMADO = teste que FALHA hoje, marcado `[ACHADO <SEVERIDADE>]`.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:setes_validators/setes_validators.dart';
import 'package:setes_web/app/shared/entity/domain/federal_id_check.dart';
import 'package:setes_web/app/shared/entity/domain/object_entity_fiscal.dart';

import 'federal_id_fence_test.dart' as fence;

const _alnum = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
String _randomValid(Random r) {
  final base = List.generate(12, (_) => _alnum[r.nextInt(_alnum.length)]).join();
  return base + FederalIdRules.cnpjCheckDigits(base)!;
}

/// Ruído SEM o NEL (o NEL tem teste próprio abaixo).
const _noise = ['.', '/', '-', ' ', '\t', ' ', '﻿', '​', ' ', '_', 'Á', 'ı', 'ſ', 'K', '０', '٣', 'a', 'é', 'ß', '😀'];

/// A decisão da API sobre o que o app ENVIA (`isValidCnpj` exato da peça — o mesmo algoritmo TS, provado pelo vetor oficial).
bool _apiAccepts(String sent) => FederalIdRules.isValidCnpj(sent);

/// Só letras/dígitos ASCII, em maiúscula — o "conteúdo" de uma inscrição (máscara e brancos não contam).
String _content(String s) => s.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');

void main() {
  test('fuzz 8.000: app OK ⇔ API aceita o que o app ENVIA; e o envio nunca perde letra/dígito ASCII do digitado', () {
    final r = Random(20261016);
    final bad = <String>[];
    for (var i = 0; i < 8000; i++) {
      final c = _randomValid(r);
      var s = r.nextBool() ? FederalIdRules.formatCnpj(c) : c;
      if (r.nextDouble() < 0.4) s = s.toLowerCase();
      if (r.nextDouble() < 0.5) {
        final p = r.nextInt(s.length + 1);
        s = s.substring(0, p) + _noise[r.nextInt(_noise.length)] + s.substring(p);
      }
      if (r.nextDouble() < 0.1) s = s.substring(0, r.nextInt(s.length + 1));
      final appOk = cnpjProblem(s) == null;
      final sent = CompanyData(cnpj: s).toJson()['cnpj'] as String;
      if (appOk != _apiAccepts(sent)) bad.add('app $appOk × api ${_apiAccepts(sent)}: ${s.runes.toList()} → $sent');
      // nunca mutila: o envio só tira máscara/brancos e sobe a minúscula — o "conteúdo" (letras e dígitos) é o MESMO do digitado
      if (_content(sent) != _content(s)) bad.add('mutilou: ${s.runes.toList()} → $sent');
    }
    expect(bad.take(10).toList(), isEmpty);
  });

  test('CNPJ com 3 letras e CNPJ com letra só na raiz NUNCA viram 11 dígitos; toJson leva as letras', () {
    for (final c in ['ABC12345000110', 'PC3D315K000193', '00000000E08G12']) {
      expect(CompanyData(cnpj: FederalIdRules.formatCnpj(c).toLowerCase()).toJson()['cnpj'], c);
    }
  });

  test('CPF: app OK ⇔ API aceita o que o app envia; CPF com letra é inválido nos dois', () {
    for (final s in ['529.982.247-25', '52998224725', ' 52998224725 ', '5299822472A', '529.982.247-2a', '11111111111', '']) {
      final appOk = cpfProblem(s) == null;
      final sent = PersonData(cpf: s).toJson()['cpf'] as String;
      expect([s, appOk], [s, FederalIdRules.isValidCpf(sent)]);
    }
  });

  // O espelho da peça foi CORRIGIDO no gate da onda 0 para aparar pelo `\s` do ECMAScript (o `trim()` do JS NÃO tira o NEL, U+0085). O
  // julgamento do formulário (`_problem`) voltou a usar `String.trim()` do Dart — que TIRA o NEL — e o `toJson` cai no `cnpj.trim()` quando a
  // peça recusa. Para o MESMO texto a API (canonicaliza pelo `trim()` do JS) recusa; o app diz OK e, com máscara, ENVIA a máscara → 400.
  // Pela UI hoje não chega: o formatter do CNPJ descarta o NEL e o `onChanged` do CPF já apara — por isso LOW.
  // CORRIGIDO na sessão: `_problem` e o `toJson` aparam pelo `FederalIdRules.trimLikeJs` (o `trim()` do JS) — julgam o MESMO que a API.
  test('[CORRIGIDO na sessão — ACHADO LOW] NEL (U+0085) nas pontas: cnpjProblem/cpfProblem dizem OK onde a API recusa o MESMO texto (e o envio leva a máscara)', () {
    const cnpjText = '\u0085PC.3D3.15K/0001-93';
    expect(FederalIdRules.normalizeCnpj(cnpjText), isNull);                   // a peça (= API) recusa o texto
    final sent = CompanyData(cnpj: cnpjText).toJson()['cnpj'] as String;
    expect(cnpjProblem(cnpjText) == null, _apiAccepts(sent));                  // ← falha: app OK, API recusa ("PC.3D3.15K/0001-93" vai mascarado)
    const cpfText = '529.982.247-25\u0085';
    expect(cpfProblem(cpfText) == null, FederalIdRules.isValidCpf(PersonData(cpf: cpfText).toJson()['cpf'] as String));
  });

  // Cerca gêmea Dart (D-CJ12): reconhece só `RegExp(` + LITERAL e o `'0123456789'.contains`. A onda 1 não lhe deu a regra 5 (valor) e o
  // próprio `CnpjInputFormatter` filtra por faixa de código (`c >= 48 && c <= 57`) — forma que a cerca não enxerga. Regressão possível;
  // nenhum uso real hoje fora do formatter (que filtra SÓ o DV, por desenho).
  // CORRIGIDO na sessão: a cerca resolve o padrão em variável, alarma faixa de código, `\p{…}`/hex e a conversão numérica sobre a inscrição;
  // as três faixas do formatter estão na lista branca com o motivo (classificação, não filtro).
  test('[CORRIGIDO na sessão — ACHADO LOW] cerca Dart: formas equivalentes de "tirar o que não é dígito" que ESCAPAM (faixa de código, \\p{…}, hex, padrão em variável, int.parse)', () {
    final escapes = <String>[
      r'String.fromCharCodes(cnpj.codeUnits.where((c) => c >= 48 && c <= 57))',
      r"cnpj.replaceAll(RegExp(r'\p{L}', unicode: true), '')",
      r"cnpj.replaceAll(RegExp(r'[^\x30-\x39]'), '')",
      r"final p = r'\D'; cnpj.replaceAll(RegExp(p), '')",
      r"cnpj.split('').where((c) => int.tryParse(c) != null).join()",
      r'int.parse(cnpj).toString().padLeft(14, "0")',
    ].where((code) => fence.strippingHitsIn(code).isEmpty).toList();
    expect(escapes, isEmpty);
  });
}
