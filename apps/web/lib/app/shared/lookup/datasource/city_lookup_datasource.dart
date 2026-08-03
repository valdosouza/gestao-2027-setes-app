import 'package:core/core.dart';

import '../entity/city_lookup_entity.dart';

/// Lookup de Cidades para listas de apoio (somente leitura).
/// Lookup DEPENDENTE (campo-lookup-fk.md, item 5): a busca exige o
/// [stateId] da UF já escolhida — a UI só abre a lista depois do estado.
/// Bind feito no Module de quem usa.
abstract class CityLookupDatasource {
  Future<List<CityLookup>> list(String filter, {required int stateId});
}

class CityLookupDatasourceImpl implements CityLookupDatasource {
  const CityLookupDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<List<CityLookup>> list(String filter, {required int stateId}) async {
    // Lookup NÃO pagina (D6), mas o envelope agora traz pageSize default 25
    // — pageSize=100 mantém o alcance da lista de apoio.
    final params = <String>[
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'stateId=$stateId',
      'pageSize=100',
    ];
    final json = await client.get('/api/cities?${params.join('&')}');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => CityLookup.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
