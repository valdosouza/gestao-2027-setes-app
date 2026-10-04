import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/object_institution.dart';
import '../../domain/usecase/institution_delete.dart';
import '../../domain/usecase/institution_get.dart';
import '../../domain/usecase/institution_getlist.dart';
import '../../domain/usecase/institution_post.dart';
import '../../domain/usecase/institution_put.dart';

import '../../../../shared/search/search_criterion.dart';

part 'institution_event.dart';
part 'institution_state.dart';

/// Orquestra o CRUD de Estabelecimento: alterna pesquisa ↔ formulário e
/// guarda o DRAFT do ObjectInstitution inteiro (skill
/// cadastro-entidade-fiscal.md) — as abas editam fatias via onChanged
/// (InstitutionDraftChanged) e salvar é 1 evento com o objeto completo.
class InstitutionBloc extends Bloc<InstitutionEvent, InstitutionBlocState> {
  InstitutionBloc({
    required this.getlist,
    required this.get,
    required this.post,
    required this.put,
    required this.delete,
  }) : super(const InstitutionListState(loading: true)) {
    on<InstitutionListRequested>(_onListRequested);
    on<InstitutionNewPressed>((event, emit) =>
        emit(const InstitutionFormState(
            draft: ObjectInstitution(), creating: true)));
    on<InstitutionEditPressed>(_onEditPressed);
    on<InstitutionDraftChanged>(_onDraftChanged);
    on<InstitutionBackToListPressed>((event, emit) => _reload(emit));
    on<InstitutionSaveRequested>(_onSaveRequested);
    on<InstitutionDeleteRequested>(_onDeleteRequested);
  }

  final InstitutionGetlist getlist;
  final InstitutionGet get;
  final InstitutionPost post;
  final InstitutionPut put;
  final InstitutionDelete delete;

  /// Últimos filtro/página/tamanho aplicados — recarga após salvar/excluir/
  /// voltar devolve o usuário exatamente onde estava (paginação, critério 6).
  String _filter = '';
  int _page = 1;
  int? _pageSize;

  /// Pesquisa avançada corrente (D-BA8: sobrevive à volta do form; o bloc
  /// é singleton do módulo — sair da tela = módulo descartado = limpa).
  SearchCriteriaValues _criteria = SearchCriteriaValues.empty;

  Future<void> _onListRequested(
      InstitutionListRequested event, Emitter<InstitutionBlocState> emit) async {
    _filter = event.filter;
    _page = event.page;
    _pageSize = event.pageSize ?? _pageSize;
    _criteria = event.criteria ?? _criteria;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<InstitutionBlocState> emit) async {
    emit(InstitutionListState(
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
          emit(InstitutionActionFailure(searchCriterionRemoved(failure)));
          return _reload(emit);
        }
        emit(InstitutionActionFailure(failure));
        emit(InstitutionListState(filter: _filter, criteria: _criteria));
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
        emit(InstitutionListState(
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

  /// Edição: busca o objeto COMPLETO (GET :id) antes de abrir o form.
  Future<void> _onEditPressed(
      InstitutionEditPressed event, Emitter<InstitutionBlocState> emit) async {
    emit(InstitutionListState(
        items: _currentItems, loading: true, criteria: _criteria));
    final result = await get(event.id);
    result.fold(
      (failure) {
        emit(InstitutionActionFailure(failure));
        emit(InstitutionListState(items: _currentItems, criteria: _criteria));
      },
      (institution) =>
          emit(InstitutionFormState(draft: institution, creating: false)),
    );
  }

  List<InstitutionListItem> get _currentItems {
    final current = state;
    return current is InstitutionListState ? current.items : const [];
  }

  /// As abas editam fatias do draft — o bloc só reemite o form atualizado.
  void _onDraftChanged(
      InstitutionDraftChanged event, Emitter<InstitutionBlocState> emit) {
    final current = state;
    if (current is! InstitutionFormState) return;
    emit(InstitutionFormState(draft: event.draft, creating: current.creating));
  }

  Future<void> _onSaveRequested(
      InstitutionSaveRequested event, Emitter<InstitutionBlocState> emit) async {
    emit(InstitutionFormState(
        draft: event.draft, creating: event.creating, saving: true));
    final result = event.creating
        ? await post(event.draft)
        : await put(event.draft);
    await result.fold(
      (failure) async {
        emit(InstitutionActionFailure(failure));
        emit(InstitutionFormState(draft: event.draft, creating: event.creating));
      },
      (_) async {
        emit(const InstitutionActionSuccess('register.saved'));
        await _reload(emit);
      },
    );
  }

  Future<void> _onDeleteRequested(
      InstitutionDeleteRequested event, Emitter<InstitutionBlocState> emit) async {
    final result = await delete(event.id);
    await result.fold(
      (failure) async => emit(InstitutionActionFailure(failure)),
      (_) async {
        emit(const InstitutionActionSuccess('register.deleted'));
        await _reload(emit);
      },
    );
  }
}
