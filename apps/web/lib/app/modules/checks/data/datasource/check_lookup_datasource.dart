import 'package:core/core.dart';

import '../../domain/entity/check_entity.dart';

/// Datasource DEDICADO das listas de apoio das ações sobre o cheque (regra:
/// a page só toca lookup datasource dedicado; lookups NÃO paginam). Continua
/// dentro do /api/checks — o módulo fala só com o seu endpoint gêmeo.
abstract class CheckLookupDatasource {
  /// Catálogo CENTRAL de bancos (FEBRABAN) — sem consumidor nesta onda (o
  /// cabeçalho do cheque é imutável); existe para paridade com a API.
  Future<List<CheckBankLookup>> banks(String filter);

  /// Contas correntes da institution (depósito/desconto/reembolso). A
  /// opção "Caixa" (id 0) é oferecida pela TELA quando o DTO da ação aceita.
  Future<List<CheckBankAccountLookup>> bankAccounts(String filter);

  /// Fornecedores da institution — a factoring costuma ser um provider.
  Future<List<CheckProviderLookup>> providers(String filter);

  /// Títulos a PAGAR abertos (uso em pagamento — evento P; máx. 100 na API).
  Future<List<CheckOpenPayable>> openPayables(String filter);
}

class CheckLookupDatasourceImpl implements CheckLookupDatasource {
  const CheckLookupDatasourceImpl({required this.client});

  final ApiClient client;

  Future<List<T>> _list<T>(
      String path, String filter, T Function(Map<String, dynamic>) fromJson) async {
    final query = filter.isEmpty ? '' : '?filter=${Uri.encodeComponent(filter)}';
    final json = await client.get('$path$query');
    final data = json['data'] as List<dynamic>? ?? [];
    return data.map((e) => fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<CheckBankLookup>> banks(String filter) =>
      _list('/api/checks/banks', filter, CheckBankLookup.fromJson);

  @override
  Future<List<CheckBankAccountLookup>> bankAccounts(String filter) =>
      _list('/api/checks/bank-accounts', filter, CheckBankAccountLookup.fromJson);

  @override
  Future<List<CheckProviderLookup>> providers(String filter) =>
      _list('/api/checks/providers', filter, CheckProviderLookup.fromJson);

  @override
  Future<List<CheckOpenPayable>> openPayables(String filter) =>
      _list('/api/checks/open-payables', filter, CheckOpenPayable.fromJson);
}
