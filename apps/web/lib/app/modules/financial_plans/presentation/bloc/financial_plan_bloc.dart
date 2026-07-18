import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/financial_plan_entity.dart';
import '../../domain/usecase/financial_plan_delete.dart';
import '../../domain/usecase/financial_plan_getlist.dart';
import '../../domain/usecase/financial_plan_post.dart';
import '../../domain/usecase/financial_plan_put.dart';

part 'financial_plan_event.dart';
part 'financial_plan_state.dart';

/// Orquestra o Plano de Contas em ÁRVORE (2º cadastro recursivo — porta do
/// reg_plano_contas.pas; padrão do tipo árvore do molde categories):
/// árvore ÚNICA ↔ formulário; criar nasce como nível raiz (FAB) ou
/// subnível (ação no nó); mover de pai é da API (PUT com parentId);
/// excluir com subníveis devolve 409 (SnackBar).
class FinancialPlanBloc extends Bloc<FinancialPlanEvent, FinancialPlanState> {
  FinancialPlanBloc({
    required this.getlist,
    required this.post,
    required this.put,
    required this.delete,
  }) : super(const FinancialPlanTreeState(loading: true)) {
    on<FinancialPlanTreeRequested>((event, emit) => _reload(emit));
    on<FinancialPlanNewPressed>(_onNewPressed);
    on<FinancialPlanEditPressed>(
        (event, emit) => emit(FinancialPlanFormState(editing: event.plan)));
    on<FinancialPlanBackToTreePressed>((event, emit) => _reload(emit));
    on<FinancialPlanSaveRequested>(_onSaveRequested);
    on<FinancialPlanDeleteRequested>(_onDeleteRequested);
  }

  final FinancialPlanGetlist getlist;
  final FinancialPlanPost post;
  final FinancialPlanPut put;
  final FinancialPlanDelete delete;

  Future<void> _reload(Emitter<FinancialPlanState> emit) async {
    emit(const FinancialPlanTreeState(loading: true));
    final result = await getlist();
    result.fold(
      (failure) {
        emit(FinancialPlanActionFailure(failure.message));
        emit(const FinancialPlanTreeState());
      },
      (items) => emit(FinancialPlanTreeState(items: items)),
    );
  }

  /// Novo NÍVEL raiz (parent null — FAB) ou SUBNÍVEL (ação no nó).
  void _onNewPressed(
      FinancialPlanNewPressed event, Emitter<FinancialPlanState> emit) {
    emit(FinancialPlanFormState(
      initialParentId: event.parent?.id,
      initialParentName: event.parent?.description,
    ));
  }

  Future<void> _onSaveRequested(
      FinancialPlanSaveRequested event, Emitter<FinancialPlanState> emit) async {
    emit(FinancialPlanFormState(
        editing: event.creating ? null : event.plan, saving: true));
    final result =
        event.creating ? await post(event.plan) : await put(event.plan);
    await result.fold(
      (failure) async {
        emit(FinancialPlanActionFailure(failure.message));
        emit(FinancialPlanFormState(
            editing: event.creating ? null : event.plan));
      },
      (_) async {
        emit(const FinancialPlanActionSuccess('register.saved'));
        await _reload(emit);
      },
    );
  }

  Future<void> _onDeleteRequested(
      FinancialPlanDeleteRequested event, Emitter<FinancialPlanState> emit) async {
    final result = await delete(event.id);
    await result.fold(
      // 409 = possui subníveis (padrão do tipo árvore — mensagem da API)
      (failure) async => emit(FinancialPlanActionFailure(failure.message)),
      (_) async {
        emit(const FinancialPlanActionSuccess('register.deleted'));
        await _reload(emit);
      },
    );
  }
}
