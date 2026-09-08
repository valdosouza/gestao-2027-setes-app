import 'package:core/core.dart';

import '../../domain/entity/bank_slip_entity.dart';

/// Datasource DEDICADO das listas de apoio da emissão de boleto (regra:
/// a page só toca lookup datasource dedicado; lookups NÃO paginam — D6).
/// Continua dentro do /api/bank-slips (sub-rotas /agreements e
/// /open-titles) — o módulo fala só com o seu endpoint gêmeo.
abstract class BankSlipLookupDatasource {
  /// Carteiras de cobrança ATIVAS (D8). Só 1 → a tela pré-seleciona.
  Future<List<BankSlipAgreementLookup>> agreements();

  /// Títulos a receber abertos sem boleto vigente (máx. 100 na API);
  /// [customerId] restringe ao cliente do 1º título marcado (D9).
  Future<List<BankSlipOpenTitle>> openTitles(String filter,
      {int? customerId});
}

class BankSlipLookupDatasourceImpl implements BankSlipLookupDatasource {
  const BankSlipLookupDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<List<BankSlipAgreementLookup>> agreements() async {
    final json = await client.get('/api/bank-slips/agreements');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) =>
            BankSlipAgreementLookup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<BankSlipOpenTitle>> openTitles(String filter,
      {int? customerId}) async {
    final params = <String>[
      if (filter.isNotEmpty) 'filter=${Uri.encodeComponent(filter)}',
      if (customerId != null) 'customerId=$customerId',
    ];
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    final json = await client.get('/api/bank-slips/open-titles$query');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => BankSlipOpenTitle.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
