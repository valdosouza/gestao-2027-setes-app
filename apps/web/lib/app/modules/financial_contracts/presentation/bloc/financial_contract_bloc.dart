import 'package:core/core.dart';
import 'package:dartz/dartz.dart' show unit;
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/financial_contract_entity.dart';
import '../../domain/usecase/financial_contract_delete.dart';
import '../../domain/usecase/financial_contract_get.dart';
import '../../domain/usecase/financial_contract_getlist.dart';
import '../../domain/usecase/financial_contract_post.dart';
import '../../domain/usecase/financial_contract_put.dart';

part 'financial_contract_event.dart';
part 'financial_contract_state.dart';

/// Orquestra os Contratos Financeiros (baixa automática por forma): lista ↔
/// formulário. A edição carrega o contrato COMPLETO (GET /:id — a lista
/// não traz a observação); o filtro da tela é REMOTO (?filter=), a lista
/// é paginada (molde bank_accounts).
class FinancialContractBloc
    extends Bloc<FinancialContractEvent, FinancialContractState> {
  FinancialContractBloc({
    required this.getlist,
    required this.get,
    required this.post,
    required this.put,
    required this.delete,
  }) : super(const FinancialContractListState(loading: true)) {
    on<FinancialContractListRequested>(_onListRequested);
    on<FinancialContractNewPressed>((event, emit) {
      _editing = null;
      emit(const FinancialContractFormState());
    });
    on<FinancialContractEditPressed>(_onEditPressed);
    on<FinancialContractBackToListPressed>((event, emit) => _reload(emit));
    on<FinancialContractSaveRequested>(_onSaveRequested);
    on<FinancialContractDeleteRequested>(_onDeleteRequested);
  }

  final FinancialContractGetlist getlist;
  final FinancialContractGet get;
  final FinancialContractPost post;
  final FinancialContractPut put;
  final FinancialContractDelete delete;

  /// Últimos filtro/página/tamanho aplicados — recarga após salvar/excluir/
  /// voltar devolve o usuário exatamente onde estava.
  String _filter = '';
  int _page = 1;
  int? _pageSize;

  /// Contrato aberto no form (null = novo) — preserva o editing nos
  /// re-emits de saving/falha.
  FinancialContractFull? _editing;

  Future<void> _onListRequested(FinancialContractListRequested event,
      Emitter<FinancialContractState> emit) async {
    _filter = event.filter;
    _page = event.page;
    _pageSize = event.pageSize ?? _pageSize;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<FinancialContractState> emit) async {
    emit(const FinancialContractListState(loading: true));
    final result = await getlist(_filter, page: _page, pageSize: _pageSize);
    await result.fold(
      (failure) async {
        emit(FinancialContractActionFailure(failure));
        emit(const FinancialContractListState());
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
        emit(FinancialContractListState(
          items: paged.items,
          filter: _filter,
          page: paged.page,
          pageSize: paged.pageSize,
          total: paged.total,
        ));
      },
    );
  }

  List<FinancialContractListItem> get _currentItems {
    final current = state;
    return current is FinancialContractListState ? current.items : const [];
  }

  Future<void> _onEditPressed(FinancialContractEditPressed event,
      Emitter<FinancialContractState> emit) async {
    emit(FinancialContractListState(items: _currentItems, loading: true));
    final result = await get(event.id);
    await result.fold(
      (failure) async {
        emit(FinancialContractActionFailure(failure));
        emit(FinancialContractListState(items: _currentItems));
      },
      (full) async {
        _editing = full;
        emit(FinancialContractFormState(editing: full));
      },
    );
  }

  Future<void> _onSaveRequested(FinancialContractSaveRequested event,
      Emitter<FinancialContractState> emit) async {
    emit(FinancialContractFormState(editing: _editing, saving: true));

    final result = event.editingId != null
        ? await put(event.editingId!, event.input)
        : (await post(event.input)).map((_) => unit);

    await result.fold(
      (failure) async {
        emit(FinancialContractActionFailure(failure));
        // Mesmo editing → o form continua montado: preserva o que o
        // usuário digitou e permite ancorar o fields[] no campo.
        emit(FinancialContractFormState(editing: _editing));
      },
      (_) async {
        emit(const FinancialContractActionSuccess('register.saved'));
        await _reload(emit);
      },
    );
  }

  Future<void> _onDeleteRequested(FinancialContractDeleteRequested event,
      Emitter<FinancialContractState> emit) async {
    final result = await delete(event.id);
    await result.fold(
      (failure) async => emit(FinancialContractActionFailure(failure)),
      (_) async {
        emit(const FinancialContractActionSuccess('register.deleted'));
        await _reload(emit);
      },
    );
  }
}
