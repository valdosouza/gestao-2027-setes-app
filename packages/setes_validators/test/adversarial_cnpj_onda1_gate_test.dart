// GATE ADVERSARIAL da ONDA 1 da frente do CNPJ alfanumérico (skill `testar-adversarial.md`, 2026-10-16) — `CnpjInputFormatter`.
// Ataque que RESISTIU = teste verde. Achado CONFIRMADO = teste que FALHAVA, marcado `[ACHADO <SEVERIDADE>]` — corrigidos na sessão (§8.10 do prompt).
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setes_validators/setes_validators.dart';

const _f = CnpjInputFormatter();
String fmt(String text) => _f.formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text)).text;

const _alnum = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
String _randomValid(Random r) {
  final base = List.generate(12, (_) => _alnum[r.nextInt(_alnum.length)]).join();
  return base + FederalIdRules.cnpjCheckDigits(base)!;
}

/// Forma do que o campo mostra: prefixo de `XX.XXX.XXX/XXXX-##`, nunca terminando num literal.
final _shape = RegExp(r'^[0-9A-Z]{0,2}(\.[0-9A-Z]{1,3}(\.[0-9A-Z]{1,3}(/[0-9A-Z]{1,4}(-[0-9]{1,2})?)?)?)?$');

const _noise = ['.', '/', '-', ' ', '\t', '\n', ' ', '\u0085', '﻿', '​', '_', 'Á', 'ı', 'ſ', 'K', '０', '٣', '¹',
  '̇', 'a', 'z', 'é', 'ß', '😀', '\uD800', '%', "'"];

void main() {
  test('todo CNPJ válido colado de qualquer jeito (máscara, minúscula, espaços, literais a mais) sai = formatCnpj e canonicaliza NELE mesmo', () {
    final r = Random(20261016);
    for (var i = 0; i < 3000; i++) {
      final c = _randomValid(r);
      final variants = [
        c,
        c.toLowerCase(),
        FederalIdRules.formatCnpj(c),
        FederalIdRules.formatCnpj(c).toLowerCase(),
        c.split('').join(' '),
        '  ${FederalIdRules.formatCnpj(c)}  ',
        c.split('').join('.'),
      ];
      for (final v in variants) {
        final out = fmt(v);
        expect([v, out], [v, FederalIdRules.formatCnpj(c)]);
        expect(FederalIdRules.canonicalizeText(out), c);
      }
    }
  });

  test('20.000 entradas adversariais (Unicode, emoji, surrogate solto, 0–50 caracteres): forma da máscara, ≤ 18, DV só dígito, idempotente, sem surrogate solto', () {
    final r = Random(7);
    final bad = <String>[];
    for (var i = 0; i < 20000; i++) {
      final len = r.nextInt(51);
      final sb = StringBuffer();
      for (var k = 0; k < len; k++) {
        sb.write(r.nextDouble() < 0.6 ? _alnum[r.nextInt(_alnum.length)] : _noise[r.nextInt(_noise.length)]);
      }
      final x = sb.toString();
      final out = fmt(x);
      // o '-' pendurado foi CORRIGIDO na sessão (teste próprio abaixo); o recorte segue por segurança
      final shown = RegExp(r'^.{15}-$').hasMatch(out) ? out.substring(0, 15) : out;
      if (!_shape.hasMatch(shown)) bad.add('forma: ${x.runes.toList()} → $out');
      if (out.length > 18) bad.add('tamanho: $out');
      if (fmt(shown) != shown) bad.add('não idempotente: $shown → ${fmt(shown)}');
      if (RegExp(r'[\uD800-\uDFFF]').hasMatch(out)) bad.add('surrogate: $out');
      final canon = FederalIdRules.canonicalizeText(out);
      if (canon == null || !RegExp(r'^[0-9A-Z]{0,12}[0-9]{0,2}$').hasMatch(canon)) bad.add('canônico: $out');
    }
    expect(bad.take(10).toList(), isEmpty);
  });

  test('o que o formatter mostra NUNCA perde caractere de um texto que já era canonicalizável e válido (nunca "conserta" para OUTRO CNPJ)', () {
    final r = Random(99);
    for (var i = 0; i < 3000; i++) {
      final c = _randomValid(r);
      // um texto que a PEÇA aceita (canonicalizável e válido) sai do formatter como a MESMA inscrição
      final x = FederalIdRules.formatCnpj(c).replaceAll('.', r.nextBool() ? '.' : ' ').toLowerCase();
      expect(FederalIdRules.normalizeCnpj(x), c);
      expect(FederalIdRules.canonicalizeText(fmt(x)), c);
    }
  });

  test('o cursor sempre fica dentro do texto (digitação, colagem de 50 caracteres, apagar tudo)', () {
    for (final t in ['', 'p', 'pc3d', 'PC.3D3.15K/0001-93', 'X' * 50, '😀😀', '.../---']) {
      final v = _f.formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: t));
      expect(v.selection.isValid, isTrue);
      expect(v.selection.baseOffset, inInclusiveRange(0, v.text.length));
    }
  });

  // Com 12 posições preenchidas e um caractere a mais que NÃO é dígito (uma letra digitada na posição do DV), o laço escreve o literal '-'
  // ANTES de descobrir que não há dígito para o DV: o campo mostra 'XX.XXX.XXX/XXXX-' e a saída não é idempotente (formatar de novo tira o
  // '-'). Cosmético — o valor fica incompleto e a marca acusa; mas é o único caso em que o formatter termina num literal.
  // CORRIGIDO na sessão (gates da onda 1): a edição que põe letra no DV NÃO ENTRA — o valor anterior fica; literal só antes de um caractere
  test('[CORRIGIDO na sessão — ACHADO LOW] letra digitada na posição do DV: não entra, nada pendurado, idempotente', () {
    final out = _f.formatEditUpdate(const TextEditingValue(text: 'PC.3D3.15K/0001'),
        const TextEditingValue(text: 'PC.3D3.15K/0001A', selection: TextSelection.collapsed(offset: 16))).text;
    expect(out, 'PC.3D3.15K/0001');
    expect(fmt('PC3D315K0001'), 'PC.3D3.15K/0001');
    expect(fmt(out), out);
  });

  // Edição no MEIO do campo: a cada tecla o cursor salta para o FIM (o formatter devolve `collapsed(text.length)` sempre) e o backspace
  // logo depois de um literal não apaga nada (o literal volta na reformatação). Mesmo comportamento do `SetesMaskFormatter` — é UX, não
  // integridade: o resultado errado fica INVÁLIDO e a marca acusa.
  test('[CORRIGIDO na sessão — ACHADO LOW] apagar o literal "/" no meio: o texto não muda e o cursor FICA onde estava', () {
    const full = 'PC.3D3.15K/0001-93';
    final out = _f.formatEditUpdate(
      const TextEditingValue(text: full, selection: TextSelection.collapsed(offset: 11)),     // cursor logo depois do '/'
      const TextEditingValue(text: 'PC.3D3.15K0001-93', selection: TextSelection.collapsed(offset: 10)), // backspace apagou o '/'
    );
    expect(out.text, full);                                       // o backspace foi engolido (resistiu: nada some)
    expect(out.selection.baseOffset, lessThanOrEqualTo(11));      // ← falha: o cursor foi para 18
  });

  // CORRIGIDO na sessão: com o campo cheio, a tecla que passaria de 14 posições NÃO ENTRA (antes o excedente saía do FIM — cortado); o
  // valor fica o anterior e o cursor onde estava. Com o campo incompleto, digitar no meio mantém o cursor depois da tecla.
  test('[CORRIGIDO na sessão — ACHADO LOW] digitar no MEIO: nada é cortado do fim e o cursor não salta para o fim', () {
    const full = 'PC.3D3.15K/0001-93';
    final cheio = _f.formatEditUpdate(
      const TextEditingValue(text: full, selection: TextSelection.collapsed(offset: 5)),
      const TextEditingValue(text: 'PC.3DX3.15K/0001-93', selection: TextSelection.collapsed(offset: 6)),
    );
    expect(cheio.text, full);
    expect(cheio.selection.baseOffset, 5);
    final meio = _f.formatEditUpdate(
      const TextEditingValue(text: 'PC.3D3.15K', selection: TextSelection.collapsed(offset: 5)),
      const TextEditingValue(text: 'PC.3DX3.15K', selection: TextSelection.collapsed(offset: 6)),
    );
    expect(meio.text, 'PC.3DX.315/K');
    expect(meio.selection.baseOffset, lessThan(meio.text.length));
  });
}
