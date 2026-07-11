import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/privilege_entity.dart';
import '../../domain/usecase/privilege_delete.dart';
import '../../domain/usecase/privilege_getlist.dart';
import '../../domain/usecase/privilege_post.dart';
import '../../domain/usecase/privilege_put.dart';

part 'privilege_event.dart';
part 'privilege_state.dart';

/// Orquestra o CRUD de Privilégio: alterna pesquisa ↔ formulário e executa
/// as operações via usecases (ARQUITETURA_MODULOS.md — a fábrica Register*
/// é apresentação pura; sucesso/erro viram estados one-shot p/ SnackBar).
class PrivilegeBloc extends Bloc<PrivilegeEvent, PrivilegeState> {
  PrivilegeBloc({
    required this.getlist,
    required this.post,
    required this.put,
    required this.delete,
  }) : super(const PrivilegeListState(loading: true)) {
    on<PrivilegeListRequested>(_onListRequested);
    on<PrivilegeNewPressed>((event, emit) => emit(const PrivilegeFormState()));
    on<PrivilegeEditPressed>(
        (event, emit) => emit(PrivilegeFormState(editing: event.privilege)));
    on<PrivilegeBackToListPressed>((event, emit) => _reload(emit));
    on<PrivilegeSaveRequested>(_onSaveRequested);
    on<PrivilegeDeleteRequested>(_onDeleteRequested);
  }

  final PrivilegeGetlist getlist;
  final PrivilegePost post;
  final PrivilegePut put;
  final PrivilegeDelete delete;

  /// Último filtro aplicado — recarga após salvar/excluir/voltar.
  String _filter = '';

  Future<void> _onListRequested(
      PrivilegeListRequested event, Emitter<PrivilegeState> emit) async {
    _filter = event.filter;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<PrivilegeState> emit) async {
    emit(const PrivilegeListState(loading: true));
    final result = await getlist(_filter);
    result.fold(
      (failure) {
        emit(PrivilegeActionFailure(failure.message));
        emit(const PrivilegeListState());
      },
      (items) => emit(PrivilegeListState(items: items)),
    );
  }

  Future<void> _onSaveRequested(
      PrivilegeSaveRequested event, Emitter<PrivilegeState> emit) async {
    emit(PrivilegeFormState(
        editing: event.creating ? null : event.privilege, saving: true));
    final result = event.creating
        ? await post(event.privilege)
        : await put(event.privilege);
    await result.fold(
      (failure) async {
        emit(PrivilegeActionFailure(failure.message));
        emit(PrivilegeFormState(
            editing: event.creating ? null : event.privilege));
      },
      (_) async {
        emit(const PrivilegeActionSuccess('register.saved'));
        await _reload(emit);
      },
    );
  }

  Future<void> _onDeleteRequested(
      PrivilegeDeleteRequested event, Emitter<PrivilegeState> emit) async {
    final result = await delete(event.id);
    await result.fold(
      (failure) async => emit(PrivilegeActionFailure(failure.message)),
      (_) async {
        emit(const PrivilegeActionSuccess('register.deleted'));
        await _reload(emit);
      },
    );
  }
}
