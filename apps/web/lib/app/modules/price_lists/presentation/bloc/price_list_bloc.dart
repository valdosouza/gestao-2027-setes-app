import 'package:core/core.dart';
import 'package:dartz/dartz.dart' show unit;
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/price_list_entity.dart';
import '../../domain/usecase/price_list_delete.dart';
import '../../domain/usecase/price_list_get.dart';
import '../../domain/usecase/price_list_getlist.dart';
import '../../domain/usecase/price_list_post.dart';
import '../../domain/usecase/price_list_put.dart';

import '../../../../shared/search/search_criterion.dart';

part 'price_list_event.dart';
part 'price_list_state.dart';

/// Orquestra as Tabelas de Preço (D7 do prompt_modulo_services.md):
/// lista ↔ formulário. Filtro REMOTO (?filter=) e paginação no molde
/// bank_accounts.
class PriceListBloc extends Bloc<PriceListEvent, PriceListState> {
  PriceListBloc({
    required this.getlist,
    required this.get,
    required this.post,
    required this.put,
    required this.delete,
  }) : super(const PriceListListState(loading: true)) {
    on<PriceListListRequested>(_onListRequested);
    on<PriceListNewPressed>((event, emit) {
      _editing = null;
      emit(const PriceListFormState());
    });
    on<PriceListEditPressed>(_onEditPressed);
    on<PriceListBackToListPressed>((event, emit) => _reload(emit));
    on<PriceListSaveRequested>(_onSaveRequested);
    on<PriceListDeleteRequested>(_onDeleteRequested);
  }

  final PriceListGetlist getlist;
  final PriceListGet get;
  final PriceListPost post;
  final PriceListPut put;
  final PriceListDelete delete;

  /// Últimos filtro/página/tamanho aplicados — recarga após salvar/excluir/
  /// voltar devolve o usuário exatamente onde estava.
  String _filter = '';
  int _page = 1;
  int? _pageSize;

  /// Pesquisa avançada corrente (D-BA8: sobrevive à volta do form; o bloc
  /// é singleton do módulo — sair da tela = módulo descartado = limpa).
  SearchCriteriaValues _criteria = SearchCriteriaValues.empty;

  /// Tabela aberta no form (null = nova) — preserva o editing nos
  /// re-emits de saving/falha.
  PriceListEntity? _editing;

  Future<void> _onListRequested(
      PriceListListRequested event, Emitter<PriceListState> emit) async {
    _filter = event.filter;
    _page = event.page;
    _pageSize = event.pageSize ?? _pageSize;
    _criteria = event.criteria ?? _criteria;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<PriceListState> emit) async {
    emit(PriceListListState(
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
          emit(PriceListActionFailure(searchCriterionRemoved(failure)));
          return _reload(emit);
        }
        emit(PriceListActionFailure(failure));
        emit(PriceListListState(filter: _filter, criteria: _criteria));
      },
      (paged) async {
        // Página esvaziou (ex.: exclusão do último item) → recua para a
        // última página existente em vez de mostrar lista vazia.
        if (paged.items.isEmpty && paged.total > 0 && paged.page > 1) {
          _page = paged.pageCount;
          return _reload(emit);
        }
        // A resposta é a fonte da verdade (clamp/config da API).
        _page = paged.page;
        _pageSize = paged.pageSize;
        emit(PriceListListState(
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

  List<PriceListEntity> get _currentItems {
    final current = state;
    return current is PriceListListState ? current.items : const [];
  }

  Future<void> _onEditPressed(
      PriceListEditPressed event, Emitter<PriceListState> emit) async {
    emit(PriceListListState(
        items: _currentItems, loading: true, criteria: _criteria));
    final result = await get(event.id);
    await result.fold(
      (failure) async {
        emit(PriceListActionFailure(failure));
        emit(PriceListListState(items: _currentItems, criteria: _criteria));
      },
      (entity) async {
        _editing = entity;
        emit(PriceListFormState(editing: entity));
      },
    );
  }

  Future<void> _onSaveRequested(
      PriceListSaveRequested event, Emitter<PriceListState> emit) async {
    emit(PriceListFormState(editing: _editing, saving: true));

    final result = event.editingId != null
        ? await put(event.editingId!, event.input)
        : (await post(event.input)).map((_) => unit);

    await result.fold(
      (failure) async {
        emit(PriceListActionFailure(failure));
        // Mesmo editing → o form continua montado: preserva o que o
        // usuário digitou e permite ancorar o fields[] no campo.
        emit(PriceListFormState(editing: _editing));
      },
      (_) async {
        emit(const PriceListActionSuccess('register.saved'));
        await _reload(emit);
      },
    );
  }

  Future<void> _onDeleteRequested(
      PriceListDeleteRequested event, Emitter<PriceListState> emit) async {
    final result = await delete(event.id);
    await result.fold(
      (failure) async => emit(PriceListActionFailure(failure)),
      (_) async {
        emit(const PriceListActionSuccess('register.deleted'));
        await _reload(emit);
      },
    );
  }
}
