import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/country_entity.dart';
import '../../domain/usecase/country_delete.dart';
import '../../domain/usecase/country_getlist.dart';
import '../../domain/usecase/country_post.dart';
import '../../domain/usecase/country_put.dart';

import '../../../../shared/search/search_criterion.dart';

part 'country_event.dart';
part 'country_state.dart';

/// Orquestra o CRUD de País: alterna pesquisa ↔ formulário e executa as
/// operações via usecases (ARQUITETURA_MODULOS.md — a fábrica Register* é
/// apresentação pura; sucesso/erro viram estados one-shot que a página
/// entrega à PONTE de feedback — Framework de Mensagens, piloto Onda A).
class CountryBloc extends Bloc<CountryEvent, CountryState> {
  CountryBloc({
    required this.getlist,
    required this.post,
    required this.put,
    required this.delete,
  }) : super(const CountryListState(loading: true)) {
    on<CountryListRequested>(_onListRequested);
    on<CountryNewPressed>((event, emit) => emit(const CountryFormState()));
    on<CountryEditPressed>(
        (event, emit) => emit(CountryFormState(editing: event.country)));
    on<CountryBackToListPressed>((event, emit) => _reload(emit));
    on<CountrySaveRequested>(_onSaveRequested);
    on<CountryDeleteRequested>(_onDeleteRequested);
  }

  final CountryGetlist getlist;
  final CountryPost post;
  final CountryPut put;
  final CountryDelete delete;

  /// Últimos filtro/página/tamanho aplicados — recarga após salvar/excluir/
  /// voltar devolve o usuário exatamente onde estava (paginação, critério 6).
  String _filter = '';
  int _page = 1;
  int? _pageSize;

  /// Pesquisa avançada corrente (D-BA8: sobrevive à volta do form; o bloc
  /// é singleton do módulo — sair da tela = módulo descartado = limpa).
  SearchCriteriaValues _criteria = SearchCriteriaValues.empty;

  Future<void> _onListRequested(
      CountryListRequested event, Emitter<CountryState> emit) async {
    _filter = event.filter;
    _page = event.page;
    _pageSize = event.pageSize ?? _pageSize;
    _criteria = event.criteria ?? _criteria;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<CountryState> emit) async {
    emit(CountryListState(
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
          emit(CountryActionFailure(searchCriterionRemoved(failure)));
          return _reload(emit);
        }
        emit(CountryActionFailure(failure));
        emit(CountryListState(filter: _filter, criteria: _criteria));
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
        emit(CountryListState(
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
      CountrySaveRequested event, Emitter<CountryState> emit) async {
    emit(CountryFormState(
        editing: event.creating ? null : event.country, saving: true));
    final result = event.creating
        ? await post(event.country)
        : await put(event.country);
    await result.fold(
      (failure) async {
        emit(CountryActionFailure(failure));
        emit(CountryFormState(
            editing: event.creating ? null : event.country));
      },
      (_) async {
        emit(const CountryActionSuccess('register.saved'));
        await _reload(emit);
      },
    );
  }

  Future<void> _onDeleteRequested(
      CountryDeleteRequested event, Emitter<CountryState> emit) async {
    final result = await delete(event.id);
    await result.fold(
      (failure) async => emit(CountryActionFailure(failure)),
      (_) async {
        emit(const CountryActionSuccess('register.deleted'));
        await _reload(emit);
      },
    );
  }
}
