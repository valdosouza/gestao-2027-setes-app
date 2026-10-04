import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/privilege_entity.dart';
import '../../domain/usecase/privilege_delete.dart';
import '../../domain/usecase/privilege_getlist.dart';
import '../../domain/usecase/privilege_post.dart';
import '../../domain/usecase/privilege_put.dart';

import '../../../../shared/search/search_criterion.dart';

part 'privilege_event.dart';
part 'privilege_state.dart';

/// Orquestra o CRUD de Privilégio: alterna pesquisa ↔ formulário e executa
/// as operações via usecases (ARQUITETURA_MODULOS.md — a fábrica Register*
/// é apresentação pura; sucesso/erro viram estados one-shot que a página
/// entrega à PONTE de feedback — Framework de Mensagens, Onda B).
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

  /// Últimos filtro/página/tamanho aplicados — recarga após salvar/excluir/
  /// voltar devolve o usuário exatamente onde estava (paginação, critério 6).
  String _filter = '';
  int _page = 1;
  int? _pageSize;

  /// Pesquisa avançada corrente (D-BA8: sobrevive à volta do form; o bloc
  /// é singleton do módulo — sair da tela = módulo descartado = limpa).
  SearchCriteriaValues _criteria = SearchCriteriaValues.empty;

  Future<void> _onListRequested(
      PrivilegeListRequested event, Emitter<PrivilegeState> emit) async {
    _filter = event.filter;
    _page = event.page;
    _pageSize = event.pageSize ?? _pageSize;
    _criteria = event.criteria ?? _criteria;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<PrivilegeState> emit) async {
    emit(PrivilegeListState(
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
          emit(PrivilegeActionFailure(searchCriterionRemoved(failure)));
          return _reload(emit);
        }
        emit(PrivilegeActionFailure(failure));
        emit(PrivilegeListState(filter: _filter, criteria: _criteria));
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
        emit(PrivilegeListState(
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
      PrivilegeSaveRequested event, Emitter<PrivilegeState> emit) async {
    emit(PrivilegeFormState(
        editing: event.creating ? null : event.privilege, saving: true));
    final result = event.creating
        ? await post(event.privilege)
        : await put(event.privilege);
    await result.fold(
      (failure) async {
        emit(PrivilegeActionFailure(failure));
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
      (failure) async => emit(PrivilegeActionFailure(failure)),
      (_) async {
        emit(const PrivilegeActionSuccess('register.deleted'));
        await _reload(emit);
      },
    );
  }
}
