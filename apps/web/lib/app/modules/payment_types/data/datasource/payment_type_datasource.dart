import 'package:core/core.dart';

import '../../domain/entity/payment_type_entity.dart';

/// Datasource remoto de Formas de Pagamento: /api/payment-types na
/// setes-api (módulo gêmeo, SEM superGuard — grupo Financeiro; escopo por
/// institution vem do JWT). Os lookups de Plano de Contas consomem
/// /api/financial-plans direto (projeção local — módulo não importa módulo).
abstract class PaymentTypeDatasource {
  /// Formas VINCULADAS à institution.
  Future<List<LinkedPaymentType>> getList();

  /// Catálogo central (lookup do form), marcando as já vinculadas.
  Future<List<PaymentTypeCatalogItem>> catalog(String filter);

  /// Plano de Contas para o lookup do form, filtrado por [kind]
  /// ('R' Resultado / 'C' Centro de Custo) — só contas vivas e ativas.
  Future<List<FinancialPlanLookupItem>> financialPlans(
      String filter, String kind);

  /// Vincula existente ([catalogId]) OU cria/reusa pela descrição.
  Future<PaymentTypePostResult> post({
    int? catalogId,
    String? description,
    String? idNfce,
    required PaymentTypeLinkAttrs attrs,
  });

  /// Atualiza o vínculo ([attrs]) e o código NF-e ([idNfce] — linha
  /// central compartilhada; null = sem código).
  Future<void> put(int id,
      {required PaymentTypeLinkAttrs attrs, String? idNfce});

  /// Desvincula (o catálogo permanece).
  Future<void> delete(int id);
}

class PaymentTypeDatasourceImpl implements PaymentTypeDatasource {
  const PaymentTypeDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<List<LinkedPaymentType>> getList() async {
    final json = await client.get('/api/payment-types');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => LinkedPaymentType.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<PaymentTypeCatalogItem>> catalog(String filter) async {
    final query = filter.isNotEmpty ? '?filter=${Uri.encodeComponent(filter)}' : '';
    final json = await client.get('/api/payment-types/catalog$query');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => PaymentTypeCatalogItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<FinancialPlanLookupItem>> financialPlans(
      String filter, String kind) async {
    final query = filter.isNotEmpty ? '?filter=${Uri.encodeComponent(filter)}' : '';
    final json = await client.get('/api/financial-plans$query');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => FinancialPlanLookupItem.fromJson(e as Map<String, dynamic>))
        .where((p) => p.kind == kind && p.active)
        .toList();
  }

  @override
  Future<PaymentTypePostResult> post({
    int? catalogId,
    String? description,
    String? idNfce,
    required PaymentTypeLinkAttrs attrs,
  }) async {
    final json = await client.post('/api/payment-types', {
      'paymentTypeId': catalogId,
      'description':   catalogId == null ? description : null,
      'idNfce':        catalogId == null ? idNfce : null,
      ...attrs.toJson(),
    });
    final data = json['data'] as Map<String, dynamic>? ?? const {};
    return PaymentTypePostResult(
      id:     (data['id'] as num).toInt(),
      reused: data['reused'] as bool? ?? false,
    );
  }

  @override
  Future<void> put(int id,
      {required PaymentTypeLinkAttrs attrs, String? idNfce}) async {
    await client.put('/api/payment-types/$id', {
      ...attrs.toJson(),
      'idNfce': idNfce,
    });
  }

  @override
  Future<void> delete(int id) async {
    await client.delete('/api/payment-types/$id');
  }
}
