// Pesquisa avançada (Infra-IA/prompts/prompt_pesquisa_avancada.md):
// serialização dos critérios para o parâmetro `criteria` da API (D-BA1) e a
// trava do datasource no /api do próprio módulo (D-BA2).
import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setes_web/app/shared/search/advanced_search_panel.dart';
import 'package:setes_web/app/shared/search/search_criteria_datasource.dart';
import 'package:setes_web/app/shared/search/search_criterion.dart';

class _FakeClient extends ApiClient {
  _FakeClient(this.response);

  final Map<String, dynamic> response;
  final paths = <String>[];

  @override
  Future<Map<String, dynamic>> get(String path) async {
    paths.add(path);
    return response;
  }
}

void main() {
  group('SearchCriteriaValues', () {
    test('from() descarta vazio: texto em branco, faixa sem pontas, lista vazia, null',
        () {
      final v = SearchCriteriaValues.from({
        'name': '   ',
        'value': const SearchRange(),
        'kind': <String>[],
        'seller': null,
        'active': false,
        'doc': ' 123 ',
      });
      expect(v.values.keys, ['active', 'doc']);
      expect(v.values['doc'], '123');
    });

    test('toQueryJson: faixa vira {from,to}, lookup viaja só o id', () {
      final v = SearchCriteriaValues.from({
        'dtRecord': const SearchRange(from: '2026-09-01', to: '2026-09-30'),
        'totalValue': const SearchRange(to: 250.0),
        'customer': const SearchLookupValue(id: 12, name: 'Acme'),
        'personType': ['F', 'J'],
        'active': true,
      });
      expect(jsonDecode(v.toQueryJson()), {
        'dtRecord': {'from': '2026-09-01', 'to': '2026-09-30'},
        'totalValue': {'to': 250.0},
        'customer': 12,
        'personType': ['F', 'J'],
        'active': true,
      });
    });

    test('toQueryParam: vazio não manda nada; preenchido vai codificado', () {
      expect(SearchCriteriaValues.empty.toQueryParam(), '');
      final p = SearchCriteriaValues.from({'city': 'São José'}).toQueryParam();
      expect(p.startsWith('criteria='), isTrue);
      expect(Uri.decodeComponent(p.substring('criteria='.length)),
          '{"city":"São José"}');
    });

    test('Q-BA16 (a): withoutRejected tira só os critérios apontados pela API', () {
      final v = SearchCriteriaValues.from({'createdAt': const SearchRange(from: '2026-01-01'), 'active': true});
      const f = Failure(message: 'x', statusCode: 422, code: 'SEARCH_CRITERION_INVALID',
          fields: [FailureField(field: 'createdAt', message: 'inválida')]);
      expect(v.withoutRejected(f)!.values.keys, ['active']);
      // falha comum, ou que não aponta critério presente: null (sem laço)
      expect(v.withoutRejected(const Failure(message: 'x', statusCode: 500)), isNull);
      expect(v.withoutRejected(const Failure(message: 'x', code: 'SEARCH_CRITERION_INVALID',
          fields: [FailureField(field: 'outro', message: 'm')])), isNull);
      // chave que a API não conhece (400) também sai
      const unknown = Failure(message: 'x', statusCode: 400, code: 'SEARCH_CRITERIA_INVALID',
          fields: [FailureField(field: 'active', message: 'não existe')]);
      expect(v.withoutRejected(unknown)!.values.keys, ['createdAt']);
    });

    test('without() remove um critério (chip x)', () {
      final v = SearchCriteriaValues.from({'a': 'x', 'b': true}).without('a');
      expect(v.values.keys, ['b']);
    });
  });

  group('número pt-BR do painel (M1 do gate socrático)', () {
    test('ponto é milhar, vírgula é decimal', () {
      expect(AdvancedSearchNumbers.parse('1.500'), 1500);
      expect(AdvancedSearchNumbers.parse('1.234,56'), 1234.56);
      expect(AdvancedSearchNumbers.parse('1500,5'), 1500.5);
      expect(AdvancedSearchNumbers.parse('42'), 42);
      expect(AdvancedSearchNumbers.parse(''), isNull);
    });
    test('formato ambíguo ou fora do teto da API é inválido (NaN)', () {
      for (final bad in ['1.5', '1,2,3', '0x10', 'abc', '99999999999999']) {
        expect(AdvancedSearchNumbers.parse(bad)!.isNaN, isTrue, reason: bad);
      }
    });
  });

  group('SearchCriteriaDatasource', () {
    test('lê os critérios do PRÓPRIO módulo', () async {
      final client = _FakeClient({
        'ok': true,
        'data': [
          {'key': 'personType', 'kind': 'options', 'labelKey': 'search.customers.personType',
            'options': ['F', 'J', 'N']},
          {'key': 'salesman', 'kind': 'lookup', 'labelKey': 'search.customers.salesman',
            'lookup': '/api/customers/salesman-lookup'},
        ],
      });
      final ds = SearchCriteriaDatasourceImpl(client: client, basePath: '/api/customers');
      final criteria = await ds.criteria();
      expect(client.paths, ['/api/customers/search-criteria']);
      expect(criteria.first.kind, SearchCriterionKind.options);
      expect(criteria.first.optionLabelKey('F'), 'search.customers.personTypeOptions.F');
      expect(criteria.last.lookup, '/api/customers/salesman-lookup');
    });

    test('tipo desconhecido (API mais nova) é descartado, não vira texto (L4)', () async {
      final client = _FakeClient({
        'ok': true,
        'data': [
          {'key': 'x', 'kind': 'geo', 'labelKey': 'search.customers.x'},
          {'key': 'active', 'kind': 'bool', 'labelKey': 'search.customers.active'},
        ],
      });
      final ds = SearchCriteriaDatasourceImpl(client: client, basePath: '/api/customers');
      expect((await ds.criteria()).map((c) => c.key), ['active']);
    });

    test('lookup fora do /api do módulo é recusado (nunca segue URL livre)', () async {
      final client = _FakeClient({'ok': true, 'data': []});
      final ds = SearchCriteriaDatasourceImpl(client: client, basePath: '/api/customers');
      expect(() => ds.lookup('/api/users/lookup', ''), throwsArgumentError);
      expect(() => ds.lookup('/api/customers-evil/x', ''), throwsArgumentError);
      await ds.lookup('/api/customers/salesman-lookup', 'jo');
      expect(client.paths, ['/api/customers/salesman-lookup?filter=jo']);
    });
  });
}
