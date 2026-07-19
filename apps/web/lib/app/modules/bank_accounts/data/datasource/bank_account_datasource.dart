import 'package:core/core.dart';

import '../../domain/entity/bank_account_entity.dart';

/// Datasource remoto de Contas Bancárias: /api/bank-accounts na setes-api
/// (módulo gêmeo — Módulo Software House; escopo por institution vem do
/// JWT). O lookup de banco é endpoint próprio do módulo
/// (/api/bank-accounts/banks — catálogo central FEBRABAN).
abstract class BankAccountDatasource {
  /// Contas da institution (a API limita a 200 — o filtro da tela é
  /// LOCAL, molde contracts/payment_types).
  Future<List<BankAccountListItem>> getList();

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
  Future<List<BankAccountListItem>> getList() async {
    final json = await client.get('/api/bank-accounts');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => BankAccountListItem.fromJson(e as Map<String, dynamic>))
        .toList();
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
