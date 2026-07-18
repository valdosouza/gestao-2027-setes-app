import 'package:core/core.dart';

import '../entity/role_lookup_entity.dart';

/// Lookup de Transportadoras (tb_carrier — escopo da institution do JWT)
/// para listas de apoio (campo-lookup-fk.md). Consumido pelo cadastro de
/// Clientes (Fase 3, decisão 11). Bind feito no Module de quem usa.
abstract class CarrierLookupDatasource {
  Future<List<RoleLookup>> list(String filter);
}

class CarrierLookupDatasourceImpl implements CarrierLookupDatasource {
  const CarrierLookupDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<List<RoleLookup>> list(String filter) async {
    final query =
        filter.isNotEmpty ? '?filter=${Uri.encodeComponent(filter)}' : '';
    final json = await client.get('/api/customers/carrier-lookup$query');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => RoleLookup.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
