part of 'institution_bloc.dart';

sealed class InstitutionEvent extends Equatable {
  const InstitutionEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a lista (também usado na abertura da página).
/// Paginação D3: [page] navega (filtro novo SEMPRE volta à página 1 na
/// tela); [pageSize] null mantém o tamanho corrente (1º load = config
/// page_size resolvida pela API — D4).
class InstitutionListRequested extends InstitutionEvent {
  const InstitutionListRequested(this.filter, {this.page = 1, this.pageSize});
  final String filter;
  final int page;
  final int? pageSize;

  @override
  List<Object?> get props => [filter, page, pageSize];
}

class InstitutionNewPressed extends InstitutionEvent {
  const InstitutionNewPressed();
}

/// Abre a edição: o bloc busca o objeto COMPLETO via GET :id.
class InstitutionEditPressed extends InstitutionEvent {
  const InstitutionEditPressed(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}

/// Uma aba editou uma fatia do draft (skill cadastro-entidade-fiscal.md).
class InstitutionDraftChanged extends InstitutionEvent {
  const InstitutionDraftChanged(this.draft);
  final ObjectInstitution draft;

  @override
  List<Object?> get props => [draft];
}

/// Volta do formulário para a pesquisa SEM salvar.
class InstitutionBackToListPressed extends InstitutionEvent {
  const InstitutionBackToListPressed();
}

/// Salvar = 1 evento com o objeto completo (cascade na API).
class InstitutionSaveRequested extends InstitutionEvent {
  const InstitutionSaveRequested({required this.draft, required this.creating});
  final ObjectInstitution draft;
  final bool creating;

  @override
  List<Object?> get props => [draft, creating];
}

class InstitutionDeleteRequested extends InstitutionEvent {
  const InstitutionDeleteRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}
