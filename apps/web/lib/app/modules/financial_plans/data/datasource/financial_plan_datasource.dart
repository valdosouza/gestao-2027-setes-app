import 'package:core/core.dart';

import '../../domain/entity/financial_plan_entity.dart';

/// Datasource remoto do Plano de Contas: /api/financial-plans na setes-api
/// (módulo gêmeo, SEM superGuard — cadastro do cliente; escopo por
/// institution vem do JWT). A lista chega ORDENADA por posit_level.
abstract class FinancialPlanDatasource {
  Future<List<FinancialPlanEntity>> getList();
  Future<int> post(FinancialPlanEntity plan);
  Future<void> put(FinancialPlanEntity plan);
  Future<void> delete(int id);
}

class FinancialPlanDatasourceImpl implements FinancialPlanDatasource {
  const FinancialPlanDatasourceImpl({required this.client});

  final ApiClient client;

  @override
  Future<List<FinancialPlanEntity>> getList() async {
    final json = await client.get('/api/financial-plans');
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => FinancialPlanEntity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// O id é gerado pelo backend (MAX+1 por institution) — o body não envia
  /// id; o posit_level nasce lá (caminho do pai + código).
  @override
  Future<int> post(FinancialPlanEntity plan) async {
    final json = await client.post('/api/financial-plans', plan.toJson());
    return (json['data']['id'] as num).toInt();
  }

  @override
  Future<void> put(FinancialPlanEntity plan) async {
    await client.put('/api/financial-plans/${plan.id}', plan.toJson());
  }

  @override
  Future<void> delete(int id) async {
    await client.delete('/api/financial-plans/$id');
  }
}
