import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/service_list_entity.dart';
import '../../domain/usecase/service_list_delete.dart';
import '../../domain/usecase/service_list_getlist.dart';
import '../../domain/usecase/service_list_post.dart';
import '../../domain/usecase/service_list_put.dart';

import '../../../../shared/search/search_criterion.dart';

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

  /// Pesquisa avançada corrente (D-BA8: sobrevive à volta do form; o bloc
  /// é singleton do módulo — sair da tela = módulo descartado = limpa).
  SearchCriteriaValues _criteria = SearchCriteriaValues.empty;

  Future<void> _onListRequested(
      ServiceListListRequested event, Emitter<ServiceListState> emit) async {
    _filter = event.filter;
    _page = event.page;
    _pageSize = event.pageSize ?? _pageSize;
    _criteria = event.criteria ?? _criteria;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<ServiceListState> emit) async {
    emit(ServiceListListState(
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
          emit(ServiceListActionFailure(searchCriterionRemoved(failure)));
          return _reload(emit);
        }
        emit(ServiceListActionFailure(failure));
        emit(ServiceListListState(filter: _filter, criteria: _criteria));
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
          criteria: _criteria,
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
