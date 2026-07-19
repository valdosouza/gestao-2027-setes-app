import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/interface_entity.dart';
import '../../domain/usecase/interface_delete.dart';
import '../../domain/usecase/interface_getlist.dart';
import '../../domain/usecase/interface_post.dart';
import '../../domain/usecase/interface_put.dart';

part 'interface_event.dart';
part 'interface_state.dart';

/// Orquestra o CRUD de Interface: alterna pesquisa ↔ formulário e executa
/// as operações via usecases (ARQUITETURA_MODULOS.md — a fábrica Register*
/// é apresentação pura; sucesso/erro viram estados one-shot que a página
/// entrega à PONTE de feedback — Framework de Mensagens, Onda B).
class InterfaceBloc extends Bloc<InterfaceEvent, InterfaceState> {
  InterfaceBloc({
    required this.getlist,
    required this.post,
    required this.put,
    required this.delete,
  }) : super(const InterfaceListState(loading: true)) {
    on<InterfaceListRequested>(_onListRequested);
    on<InterfaceNewPressed>((event, emit) => emit(const InterfaceFormState()));
    on<InterfaceEditPressed>(
        (event, emit) => emit(InterfaceFormState(editing: event.entity)));
    on<InterfaceBackToListPressed>((event, emit) => _reload(emit));
    on<InterfaceSaveRequested>(_onSaveRequested);
    on<InterfaceDeleteRequested>(_onDeleteRequested);
  }

  final InterfaceGetlist getlist;
  final InterfacePost post;
  final InterfacePut put;
  final InterfaceDelete delete;

  /// Último filtro aplicado — recarga após salvar/excluir/voltar.
  String _filter = '';

  Future<void> _onListRequested(
      InterfaceListRequested event, Emitter<InterfaceState> emit) async {
    _filter = event.filter;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<InterfaceState> emit) async {
    emit(const InterfaceListState(loading: true));
    final result = await getlist(_filter);
    result.fold(
      (failure) {
        emit(InterfaceActionFailure(failure));
        emit(const InterfaceListState());
      },
      (items) => emit(InterfaceListState(items: items)),
    );
  }

  Future<void> _onSaveRequested(
      InterfaceSaveRequested event, Emitter<InterfaceState> emit) async {
    emit(InterfaceFormState(
        editing: event.creating ? null : event.entity, saving: true));
    final result = event.creating
        ? await post(event.entity)
        : await put(event.entity);
    await result.fold(
      (failure) async {
        emit(InterfaceActionFailure(failure));
        emit(InterfaceFormState(
            editing: event.creating ? null : event.entity));
      },
      (_) async {
        emit(const InterfaceActionSuccess('register.saved'));
        await _reload(emit);
      },
    );
  }

  Future<void> _onDeleteRequested(
      InterfaceDeleteRequested event, Emitter<InterfaceState> emit) async {
    final result = await delete(event.id);
    await result.fold(
      (failure) async => emit(InterfaceActionFailure(failure)),
      (_) async {
        emit(const InterfaceActionSuccess('register.deleted'));
        await _reload(emit);
      },
    );
  }
}
