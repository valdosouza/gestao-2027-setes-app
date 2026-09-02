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

  /// Tabela aberta no form (null = nova) — preserva o editing nos
  /// re-emits de saving/falha.
  PriceListEntity? _editing;

  Future<void> _onListRequested(
      PriceListListRequested event, Emitter<PriceListState> emit) async {
    _filter = event.filter;
    _page = event.page;
    _pageSize = event.pageSize ?? _pageSize;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<PriceListState> emit) async {
    emit(const PriceListListState(loading: true));
    final result = await getlist(_filter, page: _page, pageSize: _pageSize);
    await result.fold(
      (failure) async {
        emit(PriceListActionFailure(failure));
        emit(const PriceListListState());
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
    emit(PriceListListState(items: _currentItems, loading: true));
    final result = await get(event.id);
    await result.fold(
      (failure) async {
        emit(PriceListActionFailure(failure));
        emit(PriceListListState(items: _currentItems));
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
