// GATE ADVERSARIAL da ONDA 0 da frente do CNPJ alfanumérico (skill `testar-adversarial.md`, 2026-10-15) — espelho Dart.
// Ataque que RESISTIU = teste verde que fixa a garantia. Achado CONFIRMADO = teste que FALHAVA, marcado `[ACHADO <SEVERIDADE>]`; os LOW deste
// arquivo foram CORRIGIDOS na mesma sessão de entrega (o NEL — `trim` pela semântica ECMAScript; as sondas da cerca Dart foram para a própria
// cerca, `apps/web/test/federal_id_fence_test.dart`, junto do predicado — prompt da frente §8.7). A coluna "TS" das tabelas abaixo foi MEDIDA na peça do núcleo (`fiscal-api/dist/federal-id.js`, Node 21) no mesmo
// instante — o espelho promete o MESMO resultado FORA do vetor oficial também (promessa 2 da onda).

import 'package:flutter_test/flutter_test.dart';
import 'package:setes_validators/setes_validators.dart';

const _v = 'PC3D315K000193';

/// [descrição, entrada, saída da peça TS para `canonicalizeFederalIdText`].
const _tsCanonical = <List<String?>>[
  ['NBSP nas pontas', ' $_v ', _v],
  ['BOM nas pontas', '﻿$_v﻿', _v],
  ['U+2028 nas pontas', ' $_v ', _v],
  ['U+2029 nas pontas', ' $_v ', _v],
  ['U+3000 nas pontas', '　$_v　', _v],
  ['U+1680 nas pontas', ' $_v ', _v],
  ['U+202F nas pontas', ' $_v ', _v],
  ['U+205F nas pontas', ' $_v ', _v],
  ['U+200A nas pontas', ' $_v ', _v],
  ['VT/FF nas pontas', '\u000B$_v\u000C', _v],
  ['tab/CR/LF nas pontas', '\t\r\n$_v\n', _v],
  ['zero-width space na ponta', '​$_v', null],
  ['NEL (U+0085) no começo', '\u0085$_v', null],
  ['NEL (U+0085) no fim', '$_v\u0085', null],
  ['U+180E no começo', '᠎$_v', null],
  ['ı no meio', '12ıBC34501DE35', null],
  ['ſ no começo', 'ſ2ABC34501DE35', null],
  ['ligadura ﬁ', '12ABC34501Dﬁ5', null],
  ['sinal Kelvin', '12ABC34501DE3K', null],
  ['dígito árabe-índico', '١1222333000181', null],
  ['dígito de largura total', '１1222333000181', null],
  ['NBSP no meio', '12ABC 34501DE35', null],
  ['combinante', '12ÁBC34501DE35', null],
  ['emoji', '12ABC34501DE35\u{1F600}', null],
];

/// DV da peça TS (cnpjCheckDigits) para raízes alfanuméricas aleatórias (semente 777) — fora do vetor oficial.
const _tsDv = <List<String>>[
  ['954OISKUMQIR', '04'], ['Y7XHJ5BE3AAV', '70'], ['S0IQLQF62N4V', '39'], ['Q4J8H7IKRQOG', '60'], ['BD7FC86KHRKT', '68'],
  ['K9HYFJ1WSF2O', '61'], ['GU76HHDOX2KK', '20'], ['DOFFS4USXD3H', '90'], ['7A2L2ODOMFEH', '01'], ['GGVCSUVFH3O3', '70'],
  ['EDWDAZ2XHKEV', '01'], ['MU0XR635RGKR', '00'], ['P1FEZZYVRTHS', '10'], ['HV1QD9JRU5GV', '22'], ['KIPPLF660KQ4', '69'],
  ['JC0WM0C7WW2Z', '50'], ['VWU34URC78A4', '32'], ['MF2NBW2N7VG9', '23'], ['5S24XXIZE53Z', '39'], ['ZC337G1W7OTY', '67'],
  ['PRAFNWE8IRVK', '93'], ['GABB4WCVCBZ6', '02'], ['1WVG4OVFUZIK', '02'], ['P74EYPBSA0D6', '43'], ['FD8NYRPSGQSG', '21'],
  ['0Z8C95NFSRBW', '81'], ['7I021BF9YNKD', '04'], ['6QK02PQT0X5D', '94'], ['3707SAA99UW2', '64'], ['OHA0ZOLKFPZ6', '00'],
  ['N891RBWA7865', '20'], ['6381F8Q0V70K', '39'], ['MIMY2FCTKEQG', '05'], ['E8UA6YI9DEFC', '74'], ['4L588D16X9UY', '29'],
  ['QDUQNCXVK679', '16'], ['5MC5X8REH2RM', '31'], ['8FCKS6JM58J6', '62'], ['HN1L9FZ43QHX', '46'], ['7Z5TBXXK1AUP', '16'],
];

void main() {
  group('P2 — espelho TS × Dart FORA do vetor', () {
    test('DV ASCII − 48 de 40 raízes aleatórias = o da peça TS (RESISTIU)', () {
      for (final c in _tsDv) {
        expect([c[0], FederalIdRules.cnpjCheckDigits(c[0])], [c[0], c[1]]);
        expect(FederalIdRules.isValidCnpj('${c[0]}${c[1]}'), isTrue);
      }
    });

    test('nenhum caractere do BMP fora de [0-9A-Za-z./- ] sobrevive no MEIO do texto (RESISTIU — igual ao TS)', () {
      final leaks = <String>[];
      for (var cp = 0; cp <= 0xFFFF; cp++) {
        if (cp >= 0xD800 && cp <= 0xDFFF) continue;
        final ch = String.fromCharCode(cp);
        if (RegExp(r'[0-9A-Za-z./\- ]').hasMatch(ch)) continue;
        final out = FederalIdRules.canonicalizeText('12${ch}AB');
        if (out != null) leaks.add('U+${cp.toRadixString(16).toUpperCase().padLeft(4, '0')}');
      }
      expect(leaks, isEmpty);
    });

    // O `trim()` do Dart (VM e dart2js) apara o White_Space do Unicode 6.3 — INCLUI o NEL (U+0085), que o `trim()` do JavaScript NÃO
    // apara. Mesma entrada, resultados opostos: o app aceita, a API recusa (422/400). Hoje o painel manda o texto JÁ aparado pelo Dart
    // (`SearchCriteriaValues.from`), então o efeito não aparece na pesquisa — mas o espelho deixou de ser idêntico (promessa 2).
    for (final c in _tsCanonical) {
      final achado = c[0]!.contains('NEL');   // U+180E: o Dart VM também NÃO apara — iguais (medido)
      test('${achado ? '[CORRIGIDO na sessão — ACHADO LOW] ' : ''}canonicalizar "${c[0]}" = o resultado da peça TS (${c[2] == null ? 'inválido' : 'aceito'})', () {
        expect(FederalIdRules.canonicalizeText(c[1]), c[2]);
        expect(FederalIdRules.normalizeCnpj(c[1]), c[2]);
      });
    }

    test('forma canônica estrita: nada de \\n no fim passar pelo `\$` da regex (RESISTIU)', () {
      expect(FederalIdRules.isValidCnpj('$_v\n'), isFalse);
      expect(FederalIdRules.isValidCnpj('$_v\u0085'), isFalse);
      expect(FederalIdRules.isValidCpf('52998224725\n'), isFalse);
      expect(FederalId.of(FederalIdKind.cnpj, _v.toLowerCase()), isNull);
    });

    test('SetesValidators.isValidCnpj (delegado) aceita o alfanumérico; a porta do FORMULÁRIO segue pelos dígitos (fixa a onda 0)', () {
      expect(SetesValidators.isValidCnpj(_v), isTrue);
      expect(SetesValidators.isValidCnpj(_v.replaceAll(RegExp(r'[A-Z]'), '')), isFalse);
    });
  });

  // Promessa 6 (a cerca Dart) — [CORRIGIDO na sessão — ACHADO LOW]: as 6 formas que escapavam (RegExp sem raw, argumento na linha de baixo,
  // classe negada com 1 caractere a mais, [A-Z], filtro por '0123456789', allMatches de \d) viraram SONDAS da própria cerca, junto do
  // predicado alargado (`apps/web/test/federal_id_fence_test.dart`) — um predicado só, sem reconstrução pelo texto.
}
