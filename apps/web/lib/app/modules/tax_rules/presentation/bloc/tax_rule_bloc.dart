import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/tax_rule_catalogs.dart';
import '../../domain/entity/tax_rule_draft.dart';
import '../../domain/entity/tax_rule_list_item.dart';
import '../../domain/usecase/tax_rule_delete.dart';
import '../../domain/usecase/tax_rule_get.dart';
import '../../domain/usecase/tax_rule_get_catalogs.dart';
import '../../domain/usecase/tax_rule_getlist.dart';
import '../../domain/usecase/tax_rule_post.dart';
import '../../domain/usecase/tax_rule_put.dart';

part 'tax_rule_event.dart';
part 'tax_rule_state.dart';

/// Orquestra o CRUD de Regras de Tributação: alterna pesquisa ↔ formulário
/// e guarda o DRAFT da regra inteira (seletor + peças — molde carriers):
/// as abas editam fatias via TaxRuleDraftChanged e salvar é 1 evento com o
/// objeto completo. Os catálogos fiscais dos combos são buscados UMA vez
/// (GET /catalogs) e cacheados pelo tempo de vida do bloc.
class TaxRuleBloc extends Bloc<TaxRuleEvent, TaxRuleState> {
  TaxRuleBloc({
    required this.getlist,
    required this.get,
    required this.getCatalogs,
    required this.post,
    required this.put,
    required this.delete,
  }) : super(const TaxRuleListState(loading: true)) {
    on<TaxRuleListRequested>(_onListRequested);
    on<TaxRuleNewPressed>(_onNewPressed);
    on<TaxRuleEditPressed>(_onEditPressed);
    on<TaxRuleDraftChanged>(_onDraftChanged);
    on<TaxRuleBackToListPressed>((event, emit) => _reload(emit));
    on<TaxRuleSaveRequested>(_onSaveRequested);
    on<TaxRuleDeleteRequested>(_onDeleteRequested);
  }

  final TaxRuleGetlist getlist;
  final TaxRuleGet get;
  final TaxRuleGetCatalogs getCatalogs;
  final TaxRulePost post;
  final TaxRulePut put;
  final TaxRuleDelete delete;

  /// Últimos filtro/página/tamanho aplicados — recarga após salvar/excluir/
  /// voltar devolve o usuário exatamente onde estava (paginação, critério 6).
  String _filter = '';
  int _page = 1;
  int? _pageSize;

  /// Cache dos combos fiscais (os catálogos centrais não mudam durante a
  /// sessão de cadastro).
  TaxRuleCatalogs? _catalogs;

  Future<void> _onListRequested(
      TaxRuleListRequested event, Emitter<TaxRuleState> emit) async {
    _filter = event.filter;
    _page = event.page;
    _pageSize = event.pageSize ?? _pageSize;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<TaxRuleState> emit) async {
    emit(const TaxRuleListState(loading: true));
    final result = await getlist(_filter, page: _page, pageSize: _pageSize);
    await result.fold(
      (failure) async {
        emit(TaxRuleActionFailure(failure));
        emit(const TaxRuleListState());
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
        emit(TaxRuleListState(
          items: paged.items,
          filter: _filter,
          page: paged.page,
          pageSize: paged.pageSize,
          total: paged.total,
        ));
      },
    );
  }

  List<TaxRuleListItem> get _currentItems {
    final current = state;
    return current is TaxRuleListState ? current.items : const [];
  }

  /// Garante os catálogos dos combos (uma chamada, cacheada). Falha →
  /// one-shot de erro e permanece na lista (form sem combos não abre).
  Future<TaxRuleCatalogs?> _ensureCatalogs(
      Emitter<TaxRuleState> emit) async {
    final cached = _catalogs;
    if (cached != null) return cached;
    final result = await getCatalogs();
    return result.fold(
      (failure) {
        emit(TaxRuleActionFailure(failure));
        emit(TaxRuleListState(items: _currentItems));
        return null;
      },
      (catalogs) {
        _catalogs = catalogs;
        return catalogs;
      },
    );
  }

  Future<void> _onNewPressed(
      TaxRuleNewPressed event, Emitter<TaxRuleState> emit) async {
    emit(TaxRuleListState(items: _currentItems, loading: true));
    final catalogs = await _ensureCatalogs(emit);
    if (catalogs == null) return;
    emit(TaxRuleFormState(
      draft: const TaxRuleDraft(),
      creating: true,
      catalogs: catalogs,
    ));
  }

  /// Edição: busca a regra COMPLETA (GET :id) antes de abrir o form; o
  /// nome do estado (exibição do lookup) vem da linha da lista — o GET :id
  /// devolve só o id.
  Future<void> _onEditPressed(
      TaxRuleEditPressed event, Emitter<TaxRuleState> emit) async {
    emit(TaxRuleListState(items: _currentItems, loading: true));
    final catalogs = await _ensureCatalogs(emit);
    if (catalogs == null) return;
    final result = await get(event.item.id);
    result.fold(
      (failure) {
        emit(TaxRuleActionFailure(failure));
        emit(TaxRuleListState(items: _currentItems));
      },
      (draft) => emit(TaxRuleFormState(
        draft: draft.copyWith(
            selector: draft.selector
                .copyWith(stateName: event.item.stateName ?? '')),
        creating: false,
        catalogs: catalogs,
      )),
    );
  }

  /// As abas editam fatias do draft — o bloc só reemite o form atualizado.
  void _onDraftChanged(
      TaxRuleDraftChanged event, Emitter<TaxRuleState> emit) {
    final current = state;
    if (current is! TaxRuleFormState) return;
    emit(TaxRuleFormState(
      draft: event.draft,
      creating: current.creating,
      catalogs: current.catalogs,
    ));
  }

  Future<void> _onSaveRequested(
      TaxRuleSaveRequested event, Emitter<TaxRuleState> emit) async {
    final catalogs = _catalogs ?? const TaxRuleCatalogs();
    emit(TaxRuleFormState(
      draft: event.draft,
      creating: event.creating,
      catalogs: catalogs,
      saving: true,
    ));
    final result =
        event.creating ? await post(event.draft) : await put(event.draft);
    await result.fold(
      (failure) async {
        emit(TaxRuleActionFailure(failure));
        emit(TaxRuleFormState(
          draft: event.draft,
          creating: event.creating,
          catalogs: catalogs,
        ));
      },
      (_) async {
        emit(const TaxRuleActionSuccess('register.saved'));
        await _reload(emit);
      },
    );
  }

  Future<void> _onDeleteRequested(
      TaxRuleDeleteRequested event, Emitter<TaxRuleState> emit) async {
    final result = await delete(event.id);
    await result.fold(
      (failure) async => emit(TaxRuleActionFailure(failure)),
      (_) async {
        emit(const TaxRuleActionSuccess('register.deleted'));
        await _reload(emit);
      },
    );
  }
}
