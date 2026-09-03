import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/service_list_entity.dart';
import '../../domain/usecase/service_list_delete.dart';
import '../../domain/usecase/service_list_getlist.dart';
import '../../domain/usecase/service_list_post.dart';
import '../../domain/usecase/service_list_put.dart';

part 'service_list_event.dart';
part 'service_list_state.dart';

/// Orquestra o CRUD da Lista de Serviços: alterna pesquisa ↔ formulário e
/// executa as operações via usecases (ARQUITETURA_MODULOS.md — a fábrica
/// Register* é apresentação pura; sucesso/erro viram estados one-shot que a
/// página entrega à PONTE de feedback — Framework de Mensagens, Onda B).
class ServiceListBloc extends Bloc<ServiceListEvent, ServiceListState> {
  ServiceListBloc({
    required this.getlist,
    required this.post,
    required this.put,
    required this.delete,
  }) : super(const ServiceListListState(loading: true)) {
    on<ServiceListListRequested>(_onListRequested);
    on<ServiceListNewPressed>(
        (event, emit) => emit(const ServiceListFormState()));
    on<ServiceListEditPressed>(
        (event, emit) => emit(ServiceListFormState(editing: event.item)));
    on<ServiceListBackToListPressed>((event, emit) => _reload(emit));
    on<ServiceListSaveRequested>(_onSaveRequested);
    on<ServiceListDeleteRequested>(_onDeleteRequested);
  }

  final ServiceListGetlist getlist;
  final ServiceListPost post;
  final ServiceListPut put;
  final ServiceListDelete delete;

  /// Últimos filtro/página/tamanho aplicados — recarga após salvar/excluir/
  /// voltar devolve o usuário exatamente onde estava (paginação, critério 6).
  String _filter = '';
  int _page = 1;
  int? _pageSize;

  Future<void> _onListRequested(
      ServiceListListRequested event, Emitter<ServiceListState> emit) async {
    _filter = event.filter;
    _page = event.page;
    _pageSize = event.pageSize ?? _pageSize;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<ServiceListState> emit) async {
    emit(const ServiceListListState(loading: true));
    final result = await getlist(_filter, page: _page, pageSize: _pageSize);
    await result.fold(
      (failure) async {
        emit(ServiceListActionFailure(failure));
        emit(const ServiceListListState());
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
        emit(ServiceListListState(
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
      ServiceListSaveRequested event, Emitter<ServiceListState> emit) async {
    emit(ServiceListFormState(
        editing: event.creating ? null : event.item, saving: true));
    final result =
        event.creating ? await post(event.item) : await put(event.item);
    await result.fold(
      (failure) async {
        emit(ServiceListActionFailure(failure));
        emit(ServiceListFormState(editing: event.creating ? null : event.item));
      },
      (_) async {
        emit(const ServiceListActionSuccess('register.saved'));
        await _reload(emit);
      },
    );
  }

  Future<void> _onDeleteRequested(
      ServiceListDeleteRequested event, Emitter<ServiceListState> emit) async {
    final result = await delete(event.id);
    await result.fold(
      (failure) async => emit(ServiceListActionFailure(failure)),
      (_) async {
        emit(const ServiceListActionSuccess('register.deleted'));
        await _reload(emit);
      },
    );
  }
}
