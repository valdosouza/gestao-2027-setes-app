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
/// apresentação pura; sucesso/erro viram estados one-shot p/ SnackBar).
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

  /// Último filtro aplicado — recarga após salvar/excluir/voltar.
  String _filter = '';

  Future<void> _onListRequested(
      StateListRequested event, Emitter<StateBlocState> emit) async {
    _filter = event.filter;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<StateBlocState> emit) async {
    emit(const StateListState(loading: true));
    final result = await getlist(_filter);
    result.fold(
      (failure) {
        emit(StateActionFailure(failure.message));
        emit(const StateListState());
      },
      (items) => emit(StateListState(items: items)),
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
        emit(StateActionFailure(failure.message));
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
      (failure) async => emit(StateActionFailure(failure.message)),
      (_) async {
        emit(const StateActionSuccess('register.deleted'));
        await _reload(emit);
      },
    );
  }
}
