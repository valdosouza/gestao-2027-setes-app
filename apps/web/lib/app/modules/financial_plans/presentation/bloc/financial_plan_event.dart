part of 'financial_plan_bloc.dart';

sealed class FinancialPlanEvent extends Equatable {
  const FinancialPlanEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega a ÁRVORE (abertura da página e recargas).
class FinancialPlanTreeRequested extends FinancialPlanEvent {
  const FinancialPlanTreeRequested();
}

/// Novo nível raiz ([parent] null — FAB) ou subnível do nó ([parent]).
class FinancialPlanNewPressed extends FinancialPlanEvent {
  const FinancialPlanNewPressed({this.parent});
  final FinancialPlanEntity? parent;

  @override
  List<Object?> get props => [parent];
}

class FinancialPlanEditPressed extends FinancialPlanEvent {
  const FinancialPlanEditPressed(this.plan);
  final FinancialPlanEntity plan;

  @override
  List<Object?> get props => [plan];
}

/// Volta do formulário para a árvore SEM salvar.
class FinancialPlanBackToTreePressed extends FinancialPlanEvent {
  const FinancialPlanBackToTreePressed();
}

class FinancialPlanSaveRequested extends FinancialPlanEvent {
  const FinancialPlanSaveRequested({required this.plan, required this.creating});
  final FinancialPlanEntity plan;
  final bool creating;

  @override
  List<Object?> get props => [plan, creating];
}

class FinancialPlanDeleteRequested extends FinancialPlanEvent {
  const FinancialPlanDeleteRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}
