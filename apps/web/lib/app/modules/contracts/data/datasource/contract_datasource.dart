import 'package:core/core.dart';

import '../../domain/entity/contract_entity.dart';

/// Datasource remoto de Contratos de serviço: /api/contracts na setes-api
/// (módulo gêmeo — Módulo Software House; escopo por institution vem do
/// JWT). O lookup de cliente consome /api/customers direto (projeção
/// local — módulo não importa módulo); o de produtos é endpoint próprio
/// do módulo (/api/contracts/products — só ativos).
abstract class ContractDatasource {
  /// Contratos da institution (a API limita a 200 — o filtro da tela é
  /// LOCAL, molde payment_types).
  Future<List<ContractListItem>> getList();

  /// Contrato completo (itens + paymentDay) para edição.
  Future<ContractFull> getById(int id);

  /// Clientes para o lookup do form.
  Future<List<ContractCustomerLookup>> customers(String filter);

  /// Produtos/serviços ATIVOS para o lookup dos itens.
  Future<List<ContractProductLookup>> products(String filter);

  /// Cria o contrato (itens inclusos) — devolve o id.
  Future<int> post(ContractInput input);

  /// Atualiza contrato + itens (a API sincroniza por productId).
  Future<void> put(int id, ContractInput input);

  /// Soft delete.
  Future<void> delete(int id);
}

class ContractDatasourceImpl implements ContractDatasource {
  const ContractDatasourceImpl({required this.client});

  final ApiClient client;

  static String _query(String filter) =>
      filter.isNotEmpty ? '?filter=${Uri.encodeComponent(filter)}' : '';

  @override
  Future<List<ContractListItem>> getList() async {
    final json = await client.get('/api/contracts');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => ContractListItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ContractFull> getById(int id) async {
    final json = await client.get('/api/contracts/$id');
    return ContractFull.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<List<ContractCustomerLookup>> customers(String filter) async {
    final json = await client.get('/api/customers${_query(filter)}');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => ContractCustomerLookup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<ContractProductLookup>> products(String filter) async {
    final json = await client.get('/api/contracts/products${_query(filter)}');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => ContractProductLookup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<int> post(ContractInput input) async {
    final json = await client.post('/api/contracts', input.toJson());
    final data = json['data'] as Map<String, dynamic>? ?? const {};
    return jsonInt(data['id']) ?? 0;
  }

  @override
  Future<void> put(int id, ContractInput input) async {
    await client.put('/api/contracts/$id', input.toJson());
  }

  @override
  Future<void> delete(int id) async {
    await client.delete('/api/contracts/$id');
  }
}
