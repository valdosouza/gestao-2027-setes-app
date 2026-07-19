part of 'financial_plan_bloc.dart';

sealed class FinancialPlanState extends Equatable {
  const FinancialPlanState();

  @override
  List<Object?> get props => [];
}

/// Modo ÁRVORE (buildável) — itens ordenados por posit_level.
class FinancialPlanTreeState extends FinancialPlanState {
  const FinancialPlanTreeState({this.items = const [], this.loading = false});

  final List<FinancialPlanEntity> items;
  final bool loading;

  @override
  List<Object?> get props => [items, loading];
}

/// Modo formulário (buildável). [editing] null = inclusão (nível raiz ou
/// subnível de [initialParentId]).
class FinancialPlanFormState extends FinancialPlanState {
  const FinancialPlanFormState({
    this.editing,
    this.initialParentId,
    this.initialParentName,
    this.saving = false,
  });

  final FinancialPlanEntity? editing;
  final int? initialParentId;
  final String? initialParentName;
  final bool saving;

  @override
  List<Object?> get props =>
      [editing, initialParentId, initialParentName, saving];
}

/// Efeito one-shot de sucesso (listener-only, não buildável) — a página
/// entrega à ponte (showSuccessFeedback → SnackBar, R1).
class FinancialPlanActionSuccess extends FinancialPlanState {
  const FinancialPlanActionSuccess(this.messageKey);

  /// Chave i18n ('register.saved' / 'register.deleted') — a ponte traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot de falha (listener-only, não buildável). Carrega o
/// [Failure] INTEIRO: a ponte deriva a natureza (validation × erro técnico
/// com supportRef — R7) e o fields[] ancora no campo do formulário (409
/// HAS_CHILDREN / TREE_CYCLE chegam com a mensagem da API).
class FinancialPlanActionFailure extends FinancialPlanState {
  const FinancialPlanActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
