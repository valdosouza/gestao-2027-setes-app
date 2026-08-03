part of 'privilege_bloc.dart';

sealed class PrivilegeEvent extends Equatable {
  const PrivilegeEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a lista (também usado na abertura da página).
/// Paginação D3: [page] navega (filtro novo SEMPRE volta à página 1 na
/// tela); [pageSize] null mantém o tamanho corrente (1º load = config
/// page_size resolvida pela API — D4).
class PrivilegeListRequested extends PrivilegeEvent {
  const PrivilegeListRequested(this.filter, {this.page = 1, this.pageSize});
  final String filter;
  final int page;
  final int? pageSize;

  @override
  List<Object?> get props => [filter, page, pageSize];
}

class PrivilegeNewPressed extends PrivilegeEvent {
  const PrivilegeNewPressed();
}

class PrivilegeEditPressed extends PrivilegeEvent {
  const PrivilegeEditPressed(this.privilege);
  final PrivilegeEntity privilege;

  @override
  List<Object?> get props => [privilege];
}

/// Volta do formulário para a pesquisa SEM salvar.
class PrivilegeBackToListPressed extends PrivilegeEvent {
  const PrivilegeBackToListPressed();
}

class PrivilegeSaveRequested extends PrivilegeEvent {
  const PrivilegeSaveRequested({required this.privilege, required this.creating});
  final PrivilegeEntity privilege;
  final bool creating;

  @override
  List<Object?> get props => [privilege, creating];
}

class PrivilegeDeleteRequested extends PrivilegeEvent {
  const PrivilegeDeleteRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}
