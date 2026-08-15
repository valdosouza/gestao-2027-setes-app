import 'package:core/core.dart';

import '../../domain/entity/bank_entity.dart';

/// Datasource remoto de Banco (catálogo FEBRABAN central): /api/banks na
/// setes-api. Acesso exclusivo para role='super' (superGuard por módulo).
abstract class BankDatasource {
  /// Página da lista (paginação D3): [pageSize] null deixa a API resolver a
  /// config page_size do usuário (D4).
  Future<PagedResult<BankEntity>> getList(String filter,
      {int page = 1, int? pageSize});
  Future<int> post(BankEntity bank);
  Future<void> put(BankEntity bank);
  Future<void> delete(int id);
}

class BankDatasourceImpl implements BankDatasource {
  const BankDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<PagedResult<BankEntity>> getList(String filter,
      {int page = 1, int? pageSize}) async {
    final params = [
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'page=$page',
      if (pageSize != null) 'pageSize=$pageSize',
    ];
    final json = await client.get('/api/banks?${params.join('&')}');
    return PagedResult.fromJson(json, BankEntity.fromJson);
  }

  /// O id é gerado pelo backend (MAX+1) — o body não envia id.
  /// 409 se o número FEBRABAN já estiver em uso (fields[] ancora 'number').
  @override
  Future<int> post(BankEntity bank) async {
    final json = await client.post('/api/banks', {
      'number':      bank.number,
      'description': bank.description,
    });
    return (json['data']['id'] as num).toInt();
  }

  /// O number É editável (correção permitida — não é a PK); a API mantém
  /// a unicidade com 409.
  @override
  Future<void> put(BankEntity bank) async {
    await client.put('/api/banks/${bank.id}', {
      'number':      bank.number,
      'description': bank.description,
    });
  }

  @override
  Future<void> delete(int id) async {
    await client.delete('/api/banks/$id');
  }
}
