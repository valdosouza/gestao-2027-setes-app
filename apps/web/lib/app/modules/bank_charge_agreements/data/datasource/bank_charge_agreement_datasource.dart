import 'package:core/core.dart';

import '../../domain/entity/bank_charge_agreement_entity.dart';

/// Datasource remoto de Carteiras de Cobrança: /api/bank-charge-agreements
/// na setes-api (módulo gêmeo — cadastro de CLIENTE, escopo por institution
/// do JWT). O lookup de conta corrente é endpoint DEDICADO do próprio
/// módulo (/api/bank-charge-agreements/bank-accounts — molde bank_accounts,
/// que expõe /banks do mesmo jeito); a page só toca este datasource.
abstract class BankChargeAgreementDatasource {
  /// Página da lista (filtro REMOTO por convênio/banco): [pageSize] null
  /// deixa a API resolver a config page_size do usuário.
  Future<PagedResult<BankChargeAgreementListItem>> getList(String filter,
      {int page = 1, int? pageSize});

  /// Carteira COMPLETA (GET /:id) para edição — a lista não traz encargos/
  /// instrução/protesto.
  Future<BankChargeAgreementFull> getById(int id);

  /// Contas correntes da institution para o lookup do form.
  Future<List<BankAccountLookup>> bankAccounts(String filter);

  /// Cria a carteira — devolve o id.
  Future<int> post(BankChargeAgreementInput input);

  /// Atualiza a carteira.
  Future<void> put(int id, BankChargeAgreementInput input);

  /// Soft delete.
  Future<void> delete(int id);
}

class BankChargeAgreementDatasourceImpl
    implements BankChargeAgreementDatasource {
  const BankChargeAgreementDatasourceImpl({required this.client});

  final ApiClient client;

  static String _query(String filter) =>
      filter.isNotEmpty ? '?filter=${Uri.encodeComponent(filter)}' : '';

  @override
  Future<PagedResult<BankChargeAgreementListItem>> getList(String filter,
      {int page = 1, int? pageSize}) async {
    final params = [
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      'page=$page',
      if (pageSize != null) 'pageSize=$pageSize',
    ];
    final json = await client
        .get('/api/bank-charge-agreements?${params.join('&')}');
    return PagedResult.fromJson(json, BankChargeAgreementListItem.fromJson);
  }

  @override
  Future<BankChargeAgreementFull> getById(int id) async {
    final json = await client.get('/api/bank-charge-agreements/$id');
    return BankChargeAgreementFull.fromJson(
        json['data'] as Map<String, dynamic>);
  }

  @override
  Future<List<BankAccountLookup>> bankAccounts(String filter) async {
    final json = await client
        .get('/api/bank-charge-agreements/bank-accounts${_query(filter)}');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => BankAccountLookup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<int> post(BankChargeAgreementInput input) async {
    final json =
        await client.post('/api/bank-charge-agreements', input.toJson());
    final data = json['data'] as Map<String, dynamic>? ?? const {};
    return jsonInt(data['id']) ?? 0;
  }

  @override
  Future<void> put(int id, BankChargeAgreementInput input) async {
    await client.put('/api/bank-charge-agreements/$id', input.toJson());
  }

  @override
  Future<void> delete(int id) async {
    await client.delete('/api/bank-charge-agreements/$id');
  }
}
