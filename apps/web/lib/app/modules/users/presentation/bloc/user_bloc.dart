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

  /// Últimos filtro/página/tamanho aplicados — recarga após salvar/excluir/
  /// voltar devolve o usuário exatamente onde estava (paginação, critério 6).
  String _filter = '';
  int _page = 1;
  int? _pageSize;

  Future<void> _onListRequested(
      UserListRequested event, Emitter<UserState> emit) async {
    _filter = event.filter;
    _page = event.page;
    _pageSize = event.pageSize ?? _pageSize;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<UserState> emit) async {
    emit(const UserListState(loading: true));
    final result = await getlist(_filter, page: _page, pageSize: _pageSize);
    await result.fold(
      (failure) async {
        emit(UserActionFailure(failure));
        emit(const UserListState());
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
        emit(UserListState(
          items: paged.items,
          filter: _filter,
          page: paged.page,
          pageSize: paged.pageSize,
          total: paged.total,
        ));
      },
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
