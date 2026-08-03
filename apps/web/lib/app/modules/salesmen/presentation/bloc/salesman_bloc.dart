import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/object_salesman.dart';
import '../../domain/usecase/salesman_delete.dart';
import '../../domain/usecase/salesman_get.dart';
import '../../domain/usecase/salesman_getlist.dart';
import '../../domain/usecase/salesman_post.dart';
import '../../domain/usecase/salesman_put.dart';

part 'salesman_event.dart';
part 'salesman_state.dart';

/// Orquestra o CRUD de Vendedor — Onda 2 da Entidade Única (D1): vendedor
/// é PROMOÇÃO de colaborador, então NÃO há cadeia fiscal aqui. O "novo"
/// chega como SalesmanPromotePressed (colaborador escolhido no lookup da
/// página); colaborador que já é vendedor → 409 DUP_ROLE com o id em
/// fields[0].message → one-shot SalesmanDuplicateRole (a página oferece
/// abrir em edição — padrão da casa).
class SalesmanBloc extends Bloc<SalesmanEvent, SalesmanBlocState> {
  SalesmanBloc({
    required this.getlist,
    required this.get,
    required this.post,
    required this.put,
    required this.delete,
  }) : super(const SalesmanListState(loading: true)) {
    on<SalesmanListRequested>(_onListRequested);
    on<SalesmanPromotePressed>((event, emit) => emit(SalesmanFormState(
          draft: ObjectSalesman(
            id: event.collaboratorId,
            nickTrade: event.collaboratorName,
          ),
          creating: true,
        )));
    on<SalesmanEditPressed>(_onEditPressed);
    on<SalesmanDraftChanged>(_onDraftChanged);
    on<SalesmanBackToListPressed>((event, emit) => _reload(emit));
    on<SalesmanSaveRequested>(_onSaveRequested);
    on<SalesmanDeleteRequested>(_onDeleteRequested);
  }

  final SalesmanGetlist getlist;
  final SalesmanGet get;
  final SalesmanPost post;
  final SalesmanPut put;
  final SalesmanDelete delete;

  /// Últimos filtro/página/tamanho aplicados — recarga após salvar/excluir/
  /// voltar devolve o usuário exatamente onde estava (paginação, critério 6).
  String _filter = '';
  int _page = 1;
  int? _pageSize;

  Future<void> _onListRequested(
      SalesmanListRequested event, Emitter<SalesmanBlocState> emit) async {
    _filter = event.filter;
    _page = event.page;
    _pageSize = event.pageSize ?? _pageSize;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<SalesmanBlocState> emit) async {
    emit(const SalesmanListState(loading: true));
    final result = await getlist(_filter, page: _page, pageSize: _pageSize);
    await result.fold(
      (failure) async {
        emit(SalesmanActionFailure(failure));
        emit(const SalesmanListState());
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
        emit(SalesmanListState(
          items: paged.items,
          filter: _filter,
          page: paged.page,
          pageSize: paged.pageSize,
          total: paged.total,
        ));
      },
    );
  }

  /// Edição: identificação readonly + campos do papel (GET :id).
  Future<void> _onEditPressed(
      SalesmanEditPressed event, Emitter<SalesmanBlocState> emit) async {
    emit(SalesmanListState(items: _currentItems, loading: true));
    final result = await get(event.id);
    result.fold(
      (failure) {
        emit(SalesmanActionFailure(failure));
        emit(SalesmanListState(items: _currentItems));
      },
      (salesman) => emit(SalesmanFormState(draft: salesman, creating: false)),
    );
  }

  List<SalesmanListItem> get _currentItems {
    final current = state;
    return current is SalesmanListState ? current.items : const [];
  }

  /// A página edita fatias do draft — o bloc só reemite o form atualizado.
  void _onDraftChanged(
      SalesmanDraftChanged event, Emitter<SalesmanBlocState> emit) {
    final current = state;
    if (current is! SalesmanFormState) return;
    emit(SalesmanFormState(draft: event.draft, creating: current.creating));
  }

  /// 409 de papel duplicado: erro CONHECIDO do catálogo (code == 'DUP_ROLE',
  /// R8 do Framework de Mensagens) — o id do registro existente vem em
  /// fields[0].message (contrato dos módulos de papel na API).
  int? _duplicateRoleId(Failure failure) {
    if (failure.code != 'DUP_ROLE') return null;
    final idText = failure.fieldMessage('id');
    return idText != null ? int.tryParse(idText) : null;
  }

  Future<void> _onSaveRequested(
      SalesmanSaveRequested event, Emitter<SalesmanBlocState> emit) async {
    emit(SalesmanFormState(
        draft: event.draft, creating: event.creating, saving: true));

    void onFailure(Failure failure) {
      final existingId = _duplicateRoleId(failure);
      if (existingId != null) {
        emit(SalesmanDuplicateRole(existingId));
      } else {
        emit(SalesmanActionFailure(failure));
      }
      emit(SalesmanFormState(draft: event.draft, creating: event.creating));
    }

    if (event.creating) {
      final result = await post(event.draft);
      await result.fold(
        (failure) async => onFailure(failure),
        (_) async {
          emit(const SalesmanActionSuccess('register.saved'));
          await _reload(emit);
        },
      );
    } else {
      final result = await put(event.draft);
      await result.fold(
        (failure) async => onFailure(failure),
        (_) async {
          emit(const SalesmanActionSuccess('register.saved'));
          await _reload(emit);
        },
      );
    }
  }

  Future<void> _onDeleteRequested(
      SalesmanDeleteRequested event, Emitter<SalesmanBlocState> emit) async {
    final result = await delete(event.id);
    await result.fold(
      (failure) async => emit(SalesmanActionFailure(failure)),
      (_) async {
        emit(const SalesmanActionSuccess('register.deleted'));
        await _reload(emit);
      },
    );
  }
}
