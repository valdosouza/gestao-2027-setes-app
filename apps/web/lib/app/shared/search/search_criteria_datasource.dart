import 'package:core/core.dart';

import 'search_criterion.dart';

/// Item da lista de apoio de um critério `lookup` (resposta `{ id, name }`).
class SearchLookupItem {
  const SearchLookupItem({required this.id, required this.name});

  factory SearchLookupItem.fromJson(Map<String, dynamic> json) =>
      SearchLookupItem(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? '',
      );

  final int id;
  final String name;
}

/// Datasource da pesquisa avançada (D-BA2), AMARRADO ao `/api` do módulo
/// que o instancia: o módulo do app só fala com o SEU `/api/<modulo>`
/// (ARQUITETURA_MODULOS.md) — por construção, caminho de lookup fora do
/// [basePath] é recusado (a definição vem da API, mas o app não confia
/// cegamente numa URL).
abstract class SearchCriteriaDatasource {
  Future<List<SearchCriterion>> criteria();
  Future<List<SearchLookupItem>> lookup(String path, String filter);
}

class SearchCriteriaDatasourceImpl implements SearchCriteriaDatasource {
  const SearchCriteriaDatasourceImpl({
    required this.client,
    required this.basePath,
  });

  final ApiClient client;

  /// Ex.: '/api/customers'.
  final String basePath;

  @override
  Future<List<SearchCriterion>> criteria() async {
    final json = await client.get('$basePath/search-criteria');
    final data = json['data'] as List<dynamic>? ?? const [];
    return data
        .map((e) => SearchCriterion.tryFromJson(e as Map<String, dynamic>))
        .whereType<SearchCriterion>()
        .toList();
  }

  @override
  Future<List<SearchLookupItem>> lookup(String path, String filter) async {
    if (!path.startsWith('$basePath/')) {
      throw ArgumentError('Lookup fora do módulo: $path');
    }
    final query =
        filter.isEmpty ? '' : '?filter=${Uri.encodeComponent(filter)}';
    final json = await client.get('$path$query');
    final data = json['data'] as List<dynamic>? ?? const [];
    return data
        .map((e) => SearchLookupItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
