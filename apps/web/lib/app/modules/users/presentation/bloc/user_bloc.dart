import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/users/entity/user_entity.dart';
import '../../domain/usecase/user_delete.dart';
import '../../domain/usecase/user_get.dart';
import '../../domain/usecase/user_getlist.dart';
import '../../domain/usecase/user_post.dart';
import '../../domain/usecase/user_put.dart';

part 'user_event.dart';
part 'user_state.dart';

/// Orquestra o CRUD de Usuário: alterna pesquisa ↔ formulário e executa as
/// operações via usecases (ARQUITETURA_MODULOS.md). A edição busca o
/// registro COMPLETO por id (a lista não traz nameCompany — padrão do
/// cadastro de Estabelecimento). Vínculos com institutions são seção
/// autônoma na página (fora deste bloc).
class UserBloc extends Bloc<UserEvent, UserState> {
  UserBloc({
    required this.getlist,
    required this.get,
    required this.post,
    required this.put,
    required this.delete,
  }) : super(const UserListState(loading: true)) {
    on<UserListRequested>(_onListRequested);
    on<UserNewPressed>((event, emit) => emit(const UserFormState()));
    on<UserEditPressed>(_onEditPressed);
    on<UserBackToListPressed>((event, emit) => _reload(emit));
    on<UserSaveRequested>(_onSaveRequested);
    on<UserDeleteRequested>(_onDeleteRequested);
  }

  final UserGetlist getlist;
  final UserGet get;
  final UserPost post;
  final UserPut put;
  final UserDelete delete;

  /// Último filtro aplicado — recarga após salvar/excluir/voltar.
  String _filter = '';

  Future<void> _onListRequested(
      UserListRequested event, Emitter<UserState> emit) async {
    _filter = event.filter;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<UserState> emit) async {
    emit(const UserListState(loading: true));
    final result = await getlist(_filter);
    result.fold(
      (failure) {
        emit(UserActionFailure(failure));
        emit(const UserListState());
      },
      (items) => emit(UserListState(items: items)),
    );
  }

  Future<void> _onEditPressed(
      UserEditPressed event, Emitter<UserState> emit) async {
    emit(const UserListState(loading: true));
    final result = await get(event.id);
    result.fold(
      (failure) {
        emit(UserActionFailure(failure));
        emit(const UserListState());
      },
      (user) => emit(UserFormState(editing: user)),
    );
  }

  Future<void> _onSaveRequested(
      UserSaveRequested event, Emitter<UserState> emit) async {
    emit(UserFormState(
        editing: event.creating ? null : event.user, saving: true));
    final result = event.creating
        ? await post(event.user)
        : await put(event.user);
    await result.fold(
      (failure) async {
        emit(UserActionFailure(failure));
        emit(UserFormState(editing: event.creating ? null : event.user));
      },
      (_) async {
        emit(const UserActionSuccess('register.saved'));
        await _reload(emit);
      },
    );
  }

  Future<void> _onDeleteRequested(
      UserDeleteRequested event, Emitter<UserState> emit) async {
    final result = await delete(event.id);
    await result.fold(
      (failure) async => emit(UserActionFailure(failure)),
      (_) async {
        emit(const UserActionSuccess('register.deleted'));
        await _reload(emit);
      },
    );
  }
}
