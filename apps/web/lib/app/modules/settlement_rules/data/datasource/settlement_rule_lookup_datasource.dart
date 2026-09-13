import 'package:core/core.dart';

import '../../domain/entity/settlement_rule_entity.dart';

/// Lookups DEDICADOS do form de Contrato Financeiro — endpoints próprios do
/// módulo gêmeo (/api/settlement-rules/payment-types e /bank-accounts).
/// Regra: a page só toca datasource de lookup; o módulo fala SÓ com o seu
/// /api/settlement-rules (nunca importa payment_types/bank_accounts).
abstract class SettlementRuleLookupDatasource {
  /// Formas vinculadas + habilitadas da institution, com flag hasContract.
  Future<List<PaymentTypeLookup>> paymentTypes(String filter);

  /// Contas correntes da institution ({id, label}).
  Future<List<BankAccountLookup>> bankAccounts(String filter);
}

class SettlementRuleLookupDatasourceImpl
    implements SettlementRuleLookupDatasource {
  const SettlementRuleLookupDatasourceImpl({required this.client});

  final ApiClient client;

  static String _query(String filter) =>
      filter.isNotEmpty ? '?filter=${Uri.encodeComponent(filter)}' : '';

  @override
  Future<List<PaymentTypeLookup>> paymentTypes(String filter) async {
    final json = await client
        .get('/api/settlement-rules/payment-types${_query(filter)}');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => PaymentTypeLookup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<BankAccountLookup>> bankAccounts(String filter) async {
    final json = await client
        .get('/api/settlement-rules/bank-accounts${_query(filter)}');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => BankAccountLookup.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
