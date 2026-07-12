part of 'user_bloc.dart';

sealed class UserEvent extends Equatable {
  const UserEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a lista (também usado na abertura da página).
class UserListRequested extends UserEvent {
  const UserListRequested(this.filter);
  final String filter;

  @override
  List<Object?> get props => [filter];
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
