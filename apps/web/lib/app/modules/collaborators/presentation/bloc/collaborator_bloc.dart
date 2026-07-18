import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/object_collaborator.dart';
import '../../domain/usecase/collaborator_delete.dart';
import '../../domain/usecase/collaborator_get.dart';
import '../../domain/usecase/collaborator_getlist.dart';
import '../../domain/usecase/collaborator_post.dart';
import '../../domain/usecase/collaborator_put.dart';

part 'collaborator_event.dart';
part 'collaborator_state.dart';

/// Orquestra o CRUD de Colaborador: alterna pesquisa ↔ formulário e guarda
/// o DRAFT do ObjectCollaborator inteiro (skill cadastro-entidade-fiscal.md)
/// — as abas editam fatias via onChanged (CollaboratorDraftChanged) e salvar
/// é 1 evento com o objeto completo.
///
/// Mesmo desenho do CustomerBloc: POST com reused=true vira SnackBar
/// informativo; 409 de papel duplicado (fields[0].field == 'id') vira o
/// one-shot CollaboratorDuplicateRole — a página oferece abrir em edição.
class CollaboratorBloc extends Bloc<CollaboratorEvent, CollaboratorBlocState> {
  CollaboratorBloc({
    required this.getlist,
    required this.get,
    required this.post,
    required this.put,
    required this.delete,
  }) : super(const CollaboratorListState(loading: true)) {
    on<CollaboratorListRequested>(_onListRequested);
    on<CollaboratorNewPressed>((event, emit) => emit(const
        CollaboratorFormState(draft: ObjectCollaborator(), creating: true)));
    on<CollaboratorEditPressed>(_onEditPressed);
    on<CollaboratorDraftChanged>(_onDraftChanged);
    on<CollaboratorBackToListPressed>((event, emit) => _reload(emit));
    on<CollaboratorSaveRequested>(_onSaveRequested);
    on<CollaboratorDeleteRequested>(_onDeleteRequested);
  }

  final CollaboratorGetlist getlist;
  final CollaboratorGet get;
  final CollaboratorPost post;
  final CollaboratorPut put;
  final CollaboratorDelete delete;

  /// Último filtro aplicado — recarga após salvar/excluir/voltar.
  String _filter = '';

  Future<void> _onListRequested(
      CollaboratorListRequested event, Emitter<CollaboratorBlocState> emit) async {
    _filter = event.filter;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<CollaboratorBlocState> emit) async {
    emit(const CollaboratorListState(loading: true));
    final result = await getlist(_filter);
    result.fold(
      (failure) {
        emit(CollaboratorActionFailure(failure.message));
        emit(const CollaboratorListState());
      },
      (items) => emit(CollaboratorListState(items: items)),
    );
  }

  /// Edição: busca o objeto COMPLETO (GET :id) antes de abrir o form.
  Future<void> _onEditPressed(
      CollaboratorEditPressed event, Emitter<CollaboratorBlocState> emit) async {
    emit(CollaboratorListState(items: _currentItems, loading: true));
    final result = await get(event.id);
    result.fold(
      (failure) {
        emit(CollaboratorActionFailure(failure.message));
        emit(CollaboratorListState(items: _currentItems));
      },
      (collaborator) =>
          emit(CollaboratorFormState(draft: collaborator, creating: false)),
    );
  }

  List<CollaboratorListItem> get _currentItems {
    final current = state;
    return current is CollaboratorListState ? current.items : const [];
  }

  /// As abas editam fatias do draft — o bloc só reemite o form atualizado.
  void _onDraftChanged(
      CollaboratorDraftChanged event, Emitter<CollaboratorBlocState> emit) {
    final current = state;
    if (current is! CollaboratorFormState) return;
    emit(CollaboratorFormState(draft: event.draft, creating: current.creating));
  }

  /// 409 de papel duplicado carrega o id do registro existente em
  /// fields[0].message (contrato dos módulos da cadeia fiscal na API).
  int? _duplicateRoleId(Failure failure) {
    if (failure.statusCode != 409) return null;
    final idText = failure.fieldMessage('id');
    return idText != null ? int.tryParse(idText) : null;
  }

  Future<void> _onSaveRequested(
      CollaboratorSaveRequested event, Emitter<CollaboratorBlocState> emit) async {
    emit(CollaboratorFormState(
        draft: event.draft, creating: event.creating, saving: true));

    void onFailure(Failure failure) {
      final existingId = _duplicateRoleId(failure);
      if (existingId != null) {
        emit(CollaboratorDuplicateRole(existingId));
      } else {
        emit(CollaboratorActionFailure(failure.message));
      }
      emit(CollaboratorFormState(draft: event.draft, creating: event.creating));
    }

    if (event.creating) {
      final result = await post(event.draft);
      await result.fold(
        (failure) async => onFailure(failure),
        (postResult) async {
          // reused = a API reaproveitou entity existente (decisões 1 e 9).
          emit(CollaboratorActionSuccess(postResult.reused
              ? 'forms.collaborator.reusedEntity'
              : 'register.saved'));
          await _reload(emit);
        },
      );
    } else {
      final result = await put(event.draft);
      await result.fold(
        (failure) async => onFailure(failure),
        (_) async {
          emit(const CollaboratorActionSuccess('register.saved'));
          await _reload(emit);
        },
      );
    }
  }

  Future<void> _onDeleteRequested(
      CollaboratorDeleteRequested event, Emitter<CollaboratorBlocState> emit) async {
    final result = await delete(event.id);
    await result.fold(
      (failure) async => emit(CollaboratorActionFailure(failure.message)),
      (_) async {
        emit(const CollaboratorActionSuccess('register.deleted'));
        await _reload(emit);
      },
    );
  }
}
