import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/object_provider.dart';
import '../../domain/usecase/provider_delete.dart';
import '../../domain/usecase/provider_get.dart';
import '../../domain/usecase/provider_getlist.dart';
import '../../domain/usecase/provider_post.dart';
import '../../domain/usecase/provider_put.dart';

part 'provider_event.dart';
part 'provider_state.dart';

/// Orquestra o CRUD de Fornecedor: alterna pesquisa ↔ formulário e guarda
/// o DRAFT do ObjectProvider inteiro (skill cadastro-entidade-fiscal.md) —
/// as abas editam fatias via onChanged (ProviderDraftChanged) e salvar é
/// 1 evento com o objeto completo.
///
/// Mesmo desenho do CarrierBloc (Onda 3, espelho da Onda 2): POST com
/// reused=true vira SnackBar informativo; 409 de papel duplicado
/// (code DUP_ROLE) vira o one-shot ProviderDuplicateRole — a página
/// oferece abrir em edição.
class ProviderBloc extends Bloc<ProviderEvent, ProviderBlocState> {
  ProviderBloc({
    required this.getlist,
    required this.get,
    required this.post,
    required this.put,
    required this.delete,
  }) : super(const ProviderListState(loading: true)) {
    on<ProviderListRequested>(_onListRequested);
    on<ProviderNewPressed>((event, emit) => emit(
        const ProviderFormState(draft: ObjectProvider(), creating: true)));
    on<ProviderEditPressed>(_onEditPressed);
    on<ProviderDraftChanged>(_onDraftChanged);
    on<ProviderBackToListPressed>((event, emit) => _reload(emit));
    on<ProviderSaveRequested>(_onSaveRequested);
    on<ProviderDeleteRequested>(_onDeleteRequested);
  }

  final ProviderGetlist getlist;
  final ProviderGet get;
  final ProviderPost post;
  final ProviderPut put;
  final ProviderDelete delete;

  /// Últimos filtro/página/tamanho aplicados — recarga após salvar/excluir/
  /// voltar devolve o usuário exatamente onde estava (paginação, critério 6).
  String _filter = '';
  int _page = 1;
  int? _pageSize;

  Future<void> _onListRequested(
      ProviderListRequested event, Emitter<ProviderBlocState> emit) async {
    _filter = event.filter;
    _page = event.page;
    _pageSize = event.pageSize ?? _pageSize;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<ProviderBlocState> emit) async {
    emit(const ProviderListState(loading: true));
    final result = await getlist(_filter, page: _page, pageSize: _pageSize);
    await result.fold(
      (failure) async {
        emit(ProviderActionFailure(failure));
        emit(const ProviderListState());
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
        emit(ProviderListState(
          items: paged.items,
          filter: _filter,
          page: paged.page,
          pageSize: paged.pageSize,
          total: paged.total,
        ));
      },
    );
  }

  /// Edição: busca o objeto COMPLETO (GET :id) antes de abrir o form.
  Future<void> _onEditPressed(
      ProviderEditPressed event, Emitter<ProviderBlocState> emit) async {
    emit(ProviderListState(items: _currentItems, loading: true));
    final result = await get(event.id);
    result.fold(
      (failure) {
        emit(ProviderActionFailure(failure));
        emit(ProviderListState(items: _currentItems));
      },
      (provider) => emit(ProviderFormState(draft: provider, creating: false)),
    );
  }

  List<ProviderListItem> get _currentItems {
    final current = state;
    return current is ProviderListState ? current.items : const [];
  }

  /// As abas editam fatias do draft — o bloc só reemite o form atualizado.
  void _onDraftChanged(
      ProviderDraftChanged event, Emitter<ProviderBlocState> emit) {
    final current = state;
    if (current is! ProviderFormState) return;
    emit(ProviderFormState(draft: event.draft, creating: current.creating));
  }

  /// 409 de papel duplicado: erro CONHECIDO do catálogo (code == 'DUP_ROLE',
  /// R8 do Framework de Mensagens) — o id do registro existente vem em
  /// fields[0].message (contrato dos módulos da cadeia fiscal na API).
  int? _duplicateRoleId(Failure failure) {
    if (failure.code != 'DUP_ROLE') return null;
    final idText = failure.fieldMessage('id');
    return idText != null ? int.tryParse(idText) : null;
  }

  Future<void> _onSaveRequested(
      ProviderSaveRequested event, Emitter<ProviderBlocState> emit) async {
    emit(ProviderFormState(
        draft: event.draft, creating: event.creating, saving: true));

    void onFailure(Failure failure) {
      final existingId = _duplicateRoleId(failure);
      if (existingId != null) {
        emit(ProviderDuplicateRole(existingId));
      } else {
        emit(ProviderActionFailure(failure));
      }
      emit(ProviderFormState(draft: event.draft, creating: event.creating));
    }

    if (event.creating) {
      final result = await post(event.draft);
      await result.fold(
        (failure) async => onFailure(failure),
        (postResult) async {
          // reused = a API reaproveitou entity existente (decisões 1 e 9).
          emit(ProviderActionSuccess(postResult.reused
              ? 'forms.provider.reusedEntity'
              : 'register.saved'));
          await _reload(emit);
        },
      );
    } else {
      final result = await put(event.draft);
      await result.fold(
        (failure) async => onFailure(failure),
        (_) async {
          emit(const ProviderActionSuccess('register.saved'));
          await _reload(emit);
        },
      );
    }
  }

  Future<void> _onDeleteRequested(
      ProviderDeleteRequested event, Emitter<ProviderBlocState> emit) async {
    final result = await delete(event.id);
    await result.fold(
      (failure) async => emit(ProviderActionFailure(failure)),
      (_) async {
        emit(const ProviderActionSuccess('register.deleted'));
        await _reload(emit);
      },
    );
  }
}
