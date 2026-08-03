import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/object_carrier.dart';
import '../../domain/usecase/carrier_delete.dart';
import '../../domain/usecase/carrier_get.dart';
import '../../domain/usecase/carrier_getlist.dart';
import '../../domain/usecase/carrier_post.dart';
import '../../domain/usecase/carrier_put.dart';

part 'carrier_event.dart';
part 'carrier_state.dart';

/// Orquestra o CRUD de Transportadora: alterna pesquisa ↔ formulário e
/// guarda o DRAFT do ObjectCarrier inteiro (skill
/// cadastro-entidade-fiscal.md) — as abas editam fatias via onChanged
/// (CarrierDraftChanged) e salvar é 1 evento com o objeto completo.
///
/// Mesmo desenho do CollaboratorBloc: POST com reused=true vira SnackBar
/// informativo; 409 de papel duplicado (code DUP_ROLE) vira o one-shot
/// CarrierDuplicateRole — a página oferece abrir em edição.
class CarrierBloc extends Bloc<CarrierEvent, CarrierBlocState> {
  CarrierBloc({
    required this.getlist,
    required this.get,
    required this.post,
    required this.put,
    required this.delete,
  }) : super(const CarrierListState(loading: true)) {
    on<CarrierListRequested>(_onListRequested);
    on<CarrierNewPressed>((event, emit) => emit(
        const CarrierFormState(draft: ObjectCarrier(), creating: true)));
    on<CarrierEditPressed>(_onEditPressed);
    on<CarrierDraftChanged>(_onDraftChanged);
    on<CarrierBackToListPressed>((event, emit) => _reload(emit));
    on<CarrierSaveRequested>(_onSaveRequested);
    on<CarrierDeleteRequested>(_onDeleteRequested);
  }

  final CarrierGetlist getlist;
  final CarrierGet get;
  final CarrierPost post;
  final CarrierPut put;
  final CarrierDelete delete;

  /// Últimos filtro/página/tamanho aplicados — recarga após salvar/excluir/
  /// voltar devolve o usuário exatamente onde estava (paginação, critério 6).
  String _filter = '';
  int _page = 1;
  int? _pageSize;

  Future<void> _onListRequested(
      CarrierListRequested event, Emitter<CarrierBlocState> emit) async {
    _filter = event.filter;
    _page = event.page;
    _pageSize = event.pageSize ?? _pageSize;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<CarrierBlocState> emit) async {
    emit(const CarrierListState(loading: true));
    final result = await getlist(_filter, page: _page, pageSize: _pageSize);
    await result.fold(
      (failure) async {
        emit(CarrierActionFailure(failure));
        emit(const CarrierListState());
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
        emit(CarrierListState(
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
      CarrierEditPressed event, Emitter<CarrierBlocState> emit) async {
    emit(CarrierListState(items: _currentItems, loading: true));
    final result = await get(event.id);
    result.fold(
      (failure) {
        emit(CarrierActionFailure(failure));
        emit(CarrierListState(items: _currentItems));
      },
      (carrier) => emit(CarrierFormState(draft: carrier, creating: false)),
    );
  }

  List<CarrierListItem> get _currentItems {
    final current = state;
    return current is CarrierListState ? current.items : const [];
  }

  /// As abas editam fatias do draft — o bloc só reemite o form atualizado.
  void _onDraftChanged(
      CarrierDraftChanged event, Emitter<CarrierBlocState> emit) {
    final current = state;
    if (current is! CarrierFormState) return;
    emit(CarrierFormState(draft: event.draft, creating: current.creating));
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
      CarrierSaveRequested event, Emitter<CarrierBlocState> emit) async {
    emit(CarrierFormState(
        draft: event.draft, creating: event.creating, saving: true));

    void onFailure(Failure failure) {
      final existingId = _duplicateRoleId(failure);
      if (existingId != null) {
        emit(CarrierDuplicateRole(existingId));
      } else {
        emit(CarrierActionFailure(failure));
      }
      emit(CarrierFormState(draft: event.draft, creating: event.creating));
    }

    if (event.creating) {
      final result = await post(event.draft);
      await result.fold(
        (failure) async => onFailure(failure),
        (postResult) async {
          // reused = a API reaproveitou entity existente (decisões 1 e 9).
          emit(CarrierActionSuccess(postResult.reused
              ? 'forms.carrier.reusedEntity'
              : 'register.saved'));
          await _reload(emit);
        },
      );
    } else {
      final result = await put(event.draft);
      await result.fold(
        (failure) async => onFailure(failure),
        (_) async {
          emit(const CarrierActionSuccess('register.saved'));
          await _reload(emit);
        },
      );
    }
  }

  Future<void> _onDeleteRequested(
      CarrierDeleteRequested event, Emitter<CarrierBlocState> emit) async {
    final result = await delete(event.id);
    await result.fold(
      (failure) async => emit(CarrierActionFailure(failure)),
      (_) async {
        emit(const CarrierActionSuccess('register.deleted'));
        await _reload(emit);
      },
    );
  }
}
