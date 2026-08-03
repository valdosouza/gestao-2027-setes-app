import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/state_entity.dart';
import '../../domain/usecase/state_delete.dart';
import '../../domain/usecase/state_getlist.dart';
import '../../domain/usecase/state_post.dart';
import '../../domain/usecase/state_put.dart';

part 'state_event.dart';
part 'state_state.dart';

/// Orquestra o CRUD de Estado: alterna pesquisa ↔ formulário e executa as
/// operações via usecases (ARQUITETURA_MODULOS.md — a fábrica Register* é
/// apresentação pura; sucesso/erro viram estados one-shot que a página
/// entrega à PONTE de feedback — Framework de Mensagens, Onda B).
class StateBloc extends Bloc<StateEvent, StateBlocState> {
  StateBloc({
    required this.getlist,
    required this.post,
    required this.put,
    required this.delete,
  }) : super(const StateListState(loading: true)) {
    on<StateListRequested>(_onListRequested);
    on<StateNewPressed>((event, emit) => emit(const StateFormState()));
    on<StateEditPressed>(
        (event, emit) => emit(StateFormState(editing: event.state)));
    on<StateBackToListPressed>((event, emit) => _reload(emit));
    on<StateSaveRequested>(_onSaveRequested);
    on<StateDeleteRequested>(_onDeleteRequested);
  }

  final StateGetlist getlist;
  final StatePost post;
  final StatePut put;
  final StateDelete delete;

  /// Últimos filtro/página/tamanho aplicados — recarga após salvar/excluir/
  /// voltar devolve o usuário exatamente onde estava (paginação, critério 6).
  String _filter = '';
  int _page = 1;
  int? _pageSize;

  Future<void> _onListRequested(
      StateListRequested event, Emitter<StateBlocState> emit) async {
    _filter = event.filter;
    _page = event.page;
    _pageSize = event.pageSize ?? _pageSize;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<StateBlocState> emit) async {
    emit(const StateListState(loading: true));
    final result = await getlist(_filter, page: _page, pageSize: _pageSize);
    await result.fold(
      (failure) async {
        emit(StateActionFailure(failure));
        emit(const StateListState());
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
        emit(StateListState(
          items: paged.items,
          filter: _filter,
          page: paged.page,
          pageSize: paged.pageSize,
          total: paged.total,
        ));
      },
    );
  }

  Future<void> _onSaveRequested(
      StateSaveRequested event, Emitter<StateBlocState> emit) async {
    emit(StateFormState(
        editing: event.creating ? null : event.state, saving: true));
    final result = event.creating
        ? await post(event.state)
        : await put(event.state);
    await result.fold(
      (failure) async {
        emit(StateActionFailure(failure));
        emit(StateFormState(editing: event.creating ? null : event.state));
      },
      (_) async {
        emit(const StateActionSuccess('register.saved'));
        await _reload(emit);
      },
    );
  }

  Future<void> _onDeleteRequested(
      StateDeleteRequested event, Emitter<StateBlocState> emit) async {
    final result = await delete(event.id);
    await result.fold(
      (failure) async => emit(StateActionFailure(failure)),
      (_) async {
        emit(const StateActionSuccess('register.deleted'));
        await _reload(emit);
      },
    );
  }
}
