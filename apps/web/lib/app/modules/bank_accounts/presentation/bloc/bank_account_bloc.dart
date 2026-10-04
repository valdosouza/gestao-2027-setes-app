import 'package:core/core.dart';
import 'package:dartz/dartz.dart' show unit;
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/bank_account_entity.dart';
import '../../domain/usecase/bank_account_delete.dart';
import '../../domain/usecase/bank_account_get.dart';
import '../../domain/usecase/bank_account_getlist.dart';
import '../../domain/usecase/bank_account_post.dart';
import '../../domain/usecase/bank_account_put.dart';

import '../../../../shared/search/search_criterion.dart';

part 'bank_account_event.dart';
part 'bank_account_state.dart';

/// Orquestra as Contas Bancárias (Módulo Software House): lista ↔
/// formulário. A edição carrega a conta COMPLETA (GET /:id) porque a
/// lista não traz datas nem telefone; o filtro da tela é REMOTO
/// (?filter= — paginação D7, molde customers).
class BankAccountBloc extends Bloc<BankAccountEvent, BankAccountState> {
  BankAccountBloc({
    required this.getlist,
    required this.get,
    required this.post,
    required this.put,
    required this.delete,
  }) : super(const BankAccountListState(loading: true)) {
    on<BankAccountListRequested>(_onListRequested);
    on<BankAccountNewPressed>((event, emit) {
      _editing = null;
      emit(const BankAccountFormState());
    });
    on<BankAccountEditPressed>(_onEditPressed);
    on<BankAccountBackToListPressed>((event, emit) => _reload(emit));
    on<BankAccountSaveRequested>(_onSaveRequested);
    on<BankAccountDeleteRequested>(_onDeleteRequested);
  }

  final BankAccountGetlist getlist;
  final BankAccountGet get;
  final BankAccountPost post;
  final BankAccountPut put;
  final BankAccountDelete delete;

  /// Últimos filtro/página/tamanho aplicados — recarga após salvar/excluir/
  /// voltar devolve o usuário exatamente onde estava (paginação, critério 6).
  /// D7: o filtro é REMOTO (?filter=) — o cache local `_all/_filtered`
  /// foi aposentado.
  String _filter = '';
  int _page = 1;
  int? _pageSize;

  /// Pesquisa avançada corrente (D-BA8: sobrevive à volta do form; o bloc
  /// é singleton do módulo — sair da tela = módulo descartado = limpa).
  SearchCriteriaValues _criteria = SearchCriteriaValues.empty;

  /// Conta aberta no form (null = nova) — preserva o editing nos
  /// re-emits de saving/falha.
  BankAccountFull? _editing;

  Future<void> _onListRequested(
      BankAccountListRequested event, Emitter<BankAccountState> emit) async {
    _filter = event.filter;
    _page = event.page;
    _pageSize = event.pageSize ?? _pageSize;
    _criteria = event.criteria ?? _criteria;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<BankAccountState> emit) async {
    emit(BankAccountListState(
        loading: true, filter: _filter, criteria: _criteria));
    final result = await getlist(_filter,
        page: _page, pageSize: _pageSize, criteria: _criteria);
    await result.fold(
      (failure) async {
        // Q-BA16 (a): critério recusado pela API é DESCARTADO, o usuário é
        // avisado e a lista recarrega com os demais — nunca fica travada.
        final pruned = _criteria.withoutRejected(failure);
        if (pruned != null) {
          _criteria = pruned;
          emit(BankAccountActionFailure(searchCriterionRemoved(failure)));
          return _reload(emit);
        }
        emit(BankAccountActionFailure(failure));
        emit(BankAccountListState(filter: _filter, criteria: _criteria));
      },
      (paged) async {
        // Página esvaziou (ex.: exclusão do último item) → recua para a
        // última página existente em vez de mostrar lista vazia.
        if (paged.items.isEmpty && paged.total > 0 && paged.page > 1) {
          _page = paged.pageCount;
          return _reload(emit);
        }
        // A resposta é a fonte da verdade (clamp/config da API — D4/D5).
        _page = paged.page;
        _pageSize = paged.pageSize;
        emit(BankAccountListState(
          items: paged.items,
          filter: _filter,
          criteria: _criteria,
          page: paged.page,
          pageSize: paged.pageSize,
          total: paged.total,
        ));
      },
    );
  }

  List<BankAccountListItem> get _currentItems {
    final current = state;
    return current is BankAccountListState ? current.items : const [];
  }

  Future<void> _onEditPressed(
      BankAccountEditPressed event, Emitter<BankAccountState> emit) async {
    emit(BankAccountListState(
        items: _currentItems, loading: true, criteria: _criteria));
    final result = await get(event.id);
    await result.fold(
      (failure) async {
        emit(BankAccountActionFailure(failure));
        emit(BankAccountListState(items: _currentItems, criteria: _criteria));
      },
      (full) async {
        _editing = full;
        emit(BankAccountFormState(editing: full));
      },
    );
  }

  Future<void> _onSaveRequested(
      BankAccountSaveRequested event, Emitter<BankAccountState> emit) async {
    emit(BankAccountFormState(editing: _editing, saving: true));

    final result = event.editingId != null
        ? await put(event.editingId!, event.input)
        : (await post(event.input)).map((_) => unit);

    await result.fold(
      (failure) async {
        emit(BankAccountActionFailure(failure));
        // Mesmo editing → o form continua montado: preserva o que o
        // usuário digitou e permite ancorar o fields[] no campo.
        emit(BankAccountFormState(editing: _editing));
      },
      (_) async {
        emit(const BankAccountActionSuccess('register.saved'));
        await _reload(emit);
      },
    );
  }

  Future<void> _onDeleteRequested(
      BankAccountDeleteRequested event, Emitter<BankAccountState> emit) async {
    final result = await delete(event.id);
    await result.fold(
      (failure) async => emit(BankAccountActionFailure(failure)),
      (_) async {
        emit(const BankAccountActionSuccess('register.deleted'));
        await _reload(emit);
      },
    );
  }
}
