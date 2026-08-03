part of 'user_bloc.dart';

sealed class UserEvent extends Equatable {
  const UserEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a lista (também usado na abertura da página).
/// Paginação D3: [page] navega (filtro novo SEMPRE volta à página 1 na
/// tela); [pageSize] null mantém o tamanho corrente (1º load = config
/// page_size resolvida pela API — D4).
class UserListRequested extends UserEvent {
  const UserListRequested(this.filter, {this.page = 1, this.pageSize});
  final String filter;
  final int page;
  final int? pageSize;

  @override
  List<Object?> get props => [filter, page, pageSize];
}

class UserNewPressed extends UserEvent {
  const UserNewPressed();
}

/// Edição busca o registro completo por id (a lista é resumida).
class UserEditPressed extends UserEvent {
  const UserEditPressed(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}

/// Volta do formulário para a pesquisa SEM salvar.
class UserBackToListPressed extends UserEvent {
  const UserBackToListPressed();
}

class UserSaveRequested extends UserEvent {
  const UserSaveRequested({required this.user, required this.creating});
  final UserEntity user;
  final bool creating;

  @override
  List<Object?> get props => [user, creating];
}

class UserDeleteRequested extends UserEvent {
  const UserDeleteRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}
