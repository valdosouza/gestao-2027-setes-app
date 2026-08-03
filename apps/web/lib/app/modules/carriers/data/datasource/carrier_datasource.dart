import 'package:core/core.dart';

import '../../domain/entity/object_carrier.dart';

/// Datasource remoto de Transportadora: /api/carriers na setes-api (módulo
/// gêmeo — cadastro do cliente; escopo por institution vem do JWT). POST
/// devolve { id, reused } — reused=true quando a API reaproveitou uma
/// entity existente pelo CPF/CNPJ (decisões 1 e 9 da Fase 3).
abstract class CarrierDatasource {
  /// Página da lista (paginação D3): [pageSize] null deixa a API resolver a
  /// config page_size do usuário (D4).
  Future<PagedResult<CarrierListItem>> getList(String filter,
      {int page = 1, int? pageSize});

  /// Objeto COMPLETO (entity + fiscal + 3 listas + carrier + tax).
  Future<ObjectCarrier> get(int id);
  Future<CarrierPostResult> post(ObjectCarrier carrier);
  Future<void> put(ObjectCarrier carrier);
  Future<void> delete(int id);
}

class CarrierDatasourceImpl implements CarrierDatasource {
  const CarrierDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<PagedResult<CarrierListItem>> getList(String filter,
      {int page = 1, int? pageSize}) async {
    final params = [
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'page=$page',
      if (pageSize != null) 'pageSize=$pageSize',
    ];
    final json = await client.get('/api/carriers?${params.join('&')}');
    return PagedResult.fromJson(json, CarrierListItem.fromJson);
  }

  @override
  Future<ObjectCarrier> get(int id) async {
    final json = await client.get('/api/carriers/$id');
    return ObjectCarrier.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<CarrierPostResult> post(ObjectCarrier carrier) async {
    final json = await client.post('/api/carriers', carrier.toJson());
    final data = json['data'] as Map<String, dynamic>? ?? const {};
    return CarrierPostResult(
      id:     (data['id'] as num).toInt(),
      reused: data['reused'] as bool? ?? false,
    );
  }

  @override
  Future<void> put(ObjectCarrier carrier) async {
    await client.put('/api/carriers/${carrier.id}', carrier.toJson());
  }

  @override
  Future<void> delete(int id) async {
    await client.delete('/api/carriers/$id');
  }
}
