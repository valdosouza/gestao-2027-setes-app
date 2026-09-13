import 'package:core/core.dart';
import 'package:dartz/dartz.dart' show unit;
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/settlement_rule_entity.dart';
import '../../domain/usecase/settlement_rule_delete.dart';
import '../../domain/usecase/settlement_rule_get.dart';
import '../../domain/usecase/settlement_rule_getlist.dart';
import '../../domain/usecase/settlement_rule_post.dart';
import '../../domain/usecase/settlement_rule_put.dart';

part 'settlement_rule_event.dart';
part 'settlement_rule_state.dart';

/// Orquestra os Regras de Recebimento (baixa automática por forma): lista ↔
/// formulário. A edição carrega o contrato COMPLETO (GET /:id — a lista
/// não traz a observação); o filtro da tela é REMOTO (?filter=), a lista
/// é paginada (molde bank_accounts).
class SettlementRuleBloc
    extends Bloc<SettlementRuleEvent, SettlementRuleState> {
  SettlementRuleBloc({
    required this.getlist,
    required this.get,
    required this.post,
    required this.put,
    required this.delete,
  }) : super(const SettlementRuleListState(loading: true)) {
    on<SettlementRuleListRequested>(_onListRequested);
    on<SettlementRuleNewPressed>((event, emit) {
      _editing = null;
      emit(const SettlementRuleFormState());
    });
    on<SettlementRuleEditPressed>(_onEditPressed);
    on<SettlementRuleBackToListPressed>((event, emit) => _reload(emit));
    on<SettlementRuleSaveRequested>(_onSaveRequested);
    on<SettlementRuleDeleteRequested>(_onDeleteRequested);
  }

  final SettlementRuleGetlist getlist;
  final SettlementRuleGet get;
  final SettlementRulePost post;
  final SettlementRulePut put;
  final SettlementRuleDelete delete;

  /// Últimos filtro/página/tamanho aplicados — recarga após salvar/excluir/
  /// voltar devolve o usuário exatamente onde estava.
  String _filter = '';
  int _page = 1;
  int? _pageSize;

  /// Contrato aberto no form (null = novo) — preserva o editing nos
  /// re-emits de saving/falha.
  SettlementRuleFull? _editing;

  Future<void> _onListRequested(SettlementRuleListRequested event,
      Emitter<SettlementRuleState> emit) async {
    _filter = event.filter;
    _page = event.page;
    _pageSize = event.pageSize ?? _pageSize;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<SettlementRuleState> emit) async {
    emit(const SettlementRuleListState(loading: true));
    final result = await getlist(_filter, page: _page, pageSize: _pageSize);
    await result.fold(
      (failure) async {
        emit(SettlementRuleActionFailure(failure));
        emit(const SettlementRuleListState());
      },
      (paged) async {
        // Página esvaziou (ex.: exclusão do último item) → recua para a
        // última página existente em vez de mostrar lista vazia.
        if (paged.items.isEmpty && paged.total > 0 && paged.page > 1) {
          _page = paged.pageCount;
          return _reload(emit);
        }
        _page = paged.page;
        _pageSize = paged.pageSize;
        emit(SettlementRuleListState(
          items: paged.items,
          filter: _filter,
          page: paged.page,
          pageSize: paged.pageSize,
          total: paged.total,
        ));
      },
    );
  }

  List<SettlementRuleListItem> get _currentItems {
    final current = state;
    return current is SettlementRuleListState ? current.items : const [];
  }

  Future<void> _onEditPressed(SettlementRuleEditPressed event,
      Emitter<SettlementRuleState> emit) async {
    emit(SettlementRuleListState(items: _currentItems, loading: true));
    final result = await get(event.id);
    await result.fold(
      (failure) async {
        emit(SettlementRuleActionFailure(failure));
        emit(SettlementRuleListState(items: _currentItems));
      },
      (full) async {
        _editing = full;
        emit(SettlementRuleFormState(editing: full));
      },
    );
  }

  Future<void> _onSaveRequested(SettlementRuleSaveRequested event,
      Emitter<SettlementRuleState> emit) async {
    emit(SettlementRuleFormState(editing: _editing, saving: true));

    final result = event.editingId != null
        ? await put(event.editingId!, event.input)
        : (await post(event.input)).map((_) => unit);

    await result.fold(
      (failure) async {
        emit(SettlementRuleActionFailure(failure));
        // Mesmo editing → o form continua montado: preserva o que o
        // usuário digitou e permite ancorar o fields[] no campo.
        emit(SettlementRuleFormState(editing: _editing));
      },
      (_) async {
        emit(const SettlementRuleActionSuccess('register.saved'));
        await _reload(emit);
      },
    );
  }

  Future<void> _onDeleteRequested(SettlementRuleDeleteRequested event,
      Emitter<SettlementRuleState> emit) async {
    final result = await delete(event.id);
    await result.fold(
      (failure) async => emit(SettlementRuleActionFailure(failure)),
      (_) async {
        emit(const SettlementRuleActionSuccess('register.deleted'));
        await _reload(emit);
      },
    );
  }
}
