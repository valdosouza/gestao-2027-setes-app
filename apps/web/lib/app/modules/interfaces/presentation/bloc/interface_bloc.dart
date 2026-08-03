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

  /// Últimos filtro/página/tamanho aplicados — recarga após salvar/excluir/
  /// voltar devolve o usuário exatamente onde estava (paginação, critério 6).
  String _filter = '';
  int _page = 1;
  int? _pageSize;

  Future<void> _onListRequested(
      InterfaceListRequested event, Emitter<InterfaceState> emit) async {
    _filter = event.filter;
    _page = event.page;
    _pageSize = event.pageSize ?? _pageSize;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<InterfaceState> emit) async {
    emit(const InterfaceListState(loading: true));
    final result = await getlist(_filter, page: _page, pageSize: _pageSize);
    await result.fold(
      (failure) async {
        emit(InterfaceActionFailure(failure));
        emit(const InterfaceListState());
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
        emit(InterfaceListState(
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
