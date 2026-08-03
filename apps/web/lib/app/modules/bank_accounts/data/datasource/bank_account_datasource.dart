import 'package:core/core.dart';

import '../../domain/entity/bank_account_entity.dart';

/// Datasource remoto de Contas Bancárias: /api/bank-accounts na setes-api
/// (módulo gêmeo — Módulo Software House; escopo por institution vem do
/// JWT). O lookup de banco é endpoint próprio do módulo
/// (/api/bank-accounts/banks — catálogo central FEBRABAN).
abstract class BankAccountDatasource {
  /// Página da lista (paginação D3/D7 — filtro REMOTO por banco/agência/
  /// conta/gerente): [pageSize] null deixa a API resolver a config
  /// page_size do usuário (D4).
  Future<PagedResult<BankAccountListItem>> getList(String filter,
      {int page = 1, int? pageSize});

  /// Conta completa (datas + telefone) para edição.
  Future<BankAccountFull> getById(int id);

  /// Bancos FEBRABAN do catálogo central para o lookup do form.
  Future<List<BankLookup>> banks(String filter);

  /// Cria a conta — devolve o id.
  Future<int> post(BankAccountInput input);

  /// Atualiza a conta.
  Future<void> put(int id, BankAccountInput input);

  /// Soft delete.
  Future<void> delete(int id);
}

class BankAccountDatasourceImpl implements BankAccountDatasource {
  const BankAccountDatasourceImpl({required this.client});

  final ApiClient client;

  static String _query(String filter) =>
      filter.isNotEmpty ? '?filter=${Uri.encodeComponent(filter)}' : '';

  @override
  Future<PagedResult<BankAccountListItem>> getList(String filter,
      {int page = 1, int? pageSize}) async {
    final params = [
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'page=$page',
      if (pageSize != null) 'pageSize=$pageSize',
    ];
    final json = await client.get('/api/bank-accounts?${params.join('&')}');
    return PagedResult.fromJson(json, BankAccountListItem.fromJson);
  }

  @override
  Future<BankAccountFull> getById(int id) async {
    final json = await client.get('/api/bank-accounts/$id');
    return BankAccountFull.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<List<BankLookup>> banks(String filter) async {
    final json = await client.get('/api/bank-accounts/banks${_query(filter)}');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => BankLookup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<int> post(BankAccountInput input) async {
    final json = await client.post('/api/bank-accounts', input.toJson());
    final data = json['data'] as Map<String, dynamic>? ?? const {};
    return jsonInt(data['id']) ?? 0;
  }

  @override
  Future<void> put(int id, BankAccountInput input) async {
    await client.put('/api/bank-accounts/$id', input.toJson());
  }

  @override
  Future<void> delete(int id) async {
    await client.delete('/api/bank-accounts/$id');
  }
}
