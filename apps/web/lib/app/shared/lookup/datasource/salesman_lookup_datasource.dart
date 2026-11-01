import 'package:core/core.dart';

import '../entity/role_lookup_entity.dart';

/// Lookup de Vendedores (tb_salesman — escopo da institution do JWT) para
/// listas de apoio (campo-lookup-fk.md). Consumido pelo cadastro de
/// Clientes (Fase 3, decisão 11) e pelo Pedido. Bind feito no Module de quem
/// usa, com o [path] da lista do PRÓPRIO módulo (D-PV2: a guarda por roteador
/// confere o privilégio da tela dona da URL — o pedido usa /api/orders/...).
abstract class SalesmanLookupDatasource {
  Future<List<RoleLookup>> list(String filter);
}

class SalesmanLookupDatasourceImpl implements SalesmanLookupDatasource {
  const SalesmanLookupDatasourceImpl({
    required this.client,
    this.path = '/api/customers/salesman-lookup',
  });

  final ApiClient client;

  /// Rota da lista de apoio no módulo de quem usa (só vendedores ATIVOS).
  final String path;

  @override
  Future<List<RoleLookup>> list(String filter) async {
    final query =
        filter.isNotEmpty ? '?filter=${Uri.encodeComponent(filter)}' : '';
    final json = await client.get('$path$query');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => RoleLookup.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
