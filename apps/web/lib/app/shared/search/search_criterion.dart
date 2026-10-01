import 'dart:convert';

import 'package:core/core.dart';

/// PESQUISA AVANÇADA (Infra-IA/prompts/prompt_pesquisa_avancada.md,
/// D-BA1…D-BA15): espelho Dart da definição PÚBLICA de um critério — a API
/// declara (lista branca do módulo, D-BA2) e serve por
/// `GET /api/<modulo>/search-criteria`; a expressão SQL nunca chega aqui.
///
/// O TIPO decide o controle e o operador (D-BA4): texto = contém;
/// número/valor/data = faixa de…até; lookup = registro escolhido na lista de
/// apoio do PRÓPRIO módulo; options = uma ou mais opções; bool = tri-estado.
enum SearchCriterionKind { text, number, money, date, lookup, options, bool }

class SearchCriterion {
  const SearchCriterion({
    required this.key,
    required this.kind,
    required this.labelKey,
    this.lookup,
    this.options = const [],
  });

  /// Tipo que este app não conhece (API mais nova) = null — o critério é
  /// DESCARTADO em vez de virar texto e tomar 422 (L4 do gate socrático).
  static SearchCriterion? tryFromJson(Map<String, dynamic> json) {
    final kind = SearchCriterionKind.values
        .where((k) => k.name == json['kind'])
        .firstOrNull;
    return kind == null ? null : SearchCriterion._fromJson(json, kind);
  }

  factory SearchCriterion._fromJson(
          Map<String, dynamic> json, SearchCriterionKind kind) =>
      SearchCriterion(
        key: json['key'] as String,
        kind: kind,
        labelKey: json['labelKey'] as String,
        lookup: json['lookup'] as String?,
        options: (json['options'] as List<dynamic>? ?? const [])
            .map((e) => e as String)
            .toList(),
      );

  final String key;
  final SearchCriterionKind kind;

  /// Chave i18n do rótulo (`search.<modulo>.<key>`) — traduzida no app.
  final String labelKey;

  /// Caminho da lista de apoio (só `lookup`).
  final String? lookup;

  /// Domínio permitido (só `options`) — vem da API, nunca fixo no app.
  final List<String> options;

  /// Chave i18n de uma opção de domínio (`search.<modulo>.<key>Options.<valor>`).
  String optionLabelKey(String value) => '${labelKey}Options.$value';
}

/// Faixa de…até (número, valor ou data ISO). Pontas null = sem limite.
class SearchRange {
  const SearchRange({this.from, this.to});

  final Object? from;
  final Object? to;

  bool get isEmpty => from == null && to == null;

  Map<String, Object?> toJson() => {
        if (from != null) 'from': from,
        if (to != null) 'to': to,
      };
}

/// Valor escolhido num `lookup` — o id viaja; o nome é só para o chip.
class SearchLookupValue {
  const SearchLookupValue({required this.id, required this.name});

  final int id;
  final String name;
}

/// Estado da pesquisa avançada de uma tela: chave do critério → valor
/// (String | SearchRange | SearchLookupValue | `List<String>` | bool).
/// Imutável — cada alteração devolve uma instância nova (o bloc guarda a
/// corrente, D-BA8: volta do form mantém; sair da tela limpa).
class SearchCriteriaValues {
  const SearchCriteriaValues([this.values = const {}]);

  static const empty = SearchCriteriaValues();

  final Map<String, Object> values;

  bool get isEmpty => values.isEmpty;

  SearchCriteriaValues without(String key) =>
      SearchCriteriaValues(Map.of(values)..remove(key));

  /// Q-BA16 (Valdo 2026-09-30, opção a): a API RECUSOU critério(s) — 422
  /// SEARCH_CRITERION_INVALID (valor) ou 400 SEARCH_CRITERIA_INVALID (chave
  /// que a API não conhece). Devolve os valores SEM os critérios apontados em
  /// `fields[]` para o bloc recarregar a lista e avisar; null quando a falha
  /// não é de critério ou não aponta nenhum critério presente (falha comum —
  /// nunca entra em laço).
  SearchCriteriaValues? withoutRejected(Failure failure) {
    const codes = {'SEARCH_CRITERION_INVALID', 'SEARCH_CRITERIA_INVALID'};
    if (!codes.contains(failure.code)) return null;
    final rejected = failure.fields
        .map((f) => f.field)
        .where(values.containsKey)
        .toSet();
    if (rejected.isEmpty) return null;
    return SearchCriteriaValues(
        Map.of(values)..removeWhere((key, _) => rejected.contains(key)));
  }

  /// JSON do parâmetro `criteria` (D-BA1) — só o que está preenchido.
  String toQueryJson() => jsonEncode(values.map((key, value) => MapEntry(
        key,
        switch (value) {
          SearchRange r => r.toJson(),
          SearchLookupValue l => l.id,
          _ => value,
        },
      )));

  /// Fragmento `criteria=<json>` para a query string ('' quando vazio).
  String toQueryParam() =>
      isEmpty ? '' : 'criteria=${Uri.encodeComponent(toQueryJson())}';

  /// Normaliza a entrada do painel: descarta vazio (texto em branco, faixa
  /// sem pontas, lista vazia) — o que sobra é o que vira chip.
  static SearchCriteriaValues from(Map<String, Object?> raw) {
    final out = <String, Object>{};
    raw.forEach((key, value) {
      final keep = switch (value) {
        null => false,
        String s => s.trim().isNotEmpty,
        SearchRange r => !r.isEmpty,
        List<dynamic> l => l.isNotEmpty,
        _ => true,
      };
      if (keep) out[key] = value is String ? value.trim() : value!;
    });
    return SearchCriteriaValues(out);
  }
}

/// Falha a exibir quando critérios foram DESCARTADOS (Q-BA16 a): a mensagem é
/// chave i18n (a ponte de feedback traduz) e mantém os `fields[]` da API —
/// o usuário vê qual critério saiu e por quê.
Failure searchCriterionRemoved(Failure original) => Failure(
      message: 'search.criterionRemoved',
      statusCode: original.statusCode,
      fields: original.fields,
      code: original.code,
    );
