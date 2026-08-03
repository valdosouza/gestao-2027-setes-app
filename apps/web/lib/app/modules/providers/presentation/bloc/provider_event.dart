part of 'provider_bloc.dart';

sealed class ProviderEvent extends Equatable {
  const ProviderEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a pesquisa (também usado na abertura da página).
/// Paginação D3: [page] navega (filtro novo SEMPRE volta à página 1 na
/// tela); [pageSize] null mantém o tamanho corrente (1º load = config
/// page_size resolvida pela API — D4).
class ProviderListRequested extends ProviderEvent {
  const ProviderListRequested(this.filter, {this.page = 1, this.pageSize});
  final String filter;
  final int page;
  final int? pageSize;

  @override
  List<Object?> get props => [filter, page, pageSize];
}

class ProviderNewPressed extends ProviderEvent {
  const ProviderNewPressed();
}

/// Abre a edição: o bloc busca o objeto COMPLETO via GET :id. Também usado
/// pelo dialog do 409 de papel duplicado (abrir o registro existente).
class ProviderEditPressed extends ProviderEvent {
  const ProviderEditPressed(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}

/// Uma aba editou uma fatia do draft.
class ProviderDraftChanged extends ProviderEvent {
  const ProviderDraftChanged(this.draft);
  final ObjectProvider draft;

  @override
  List<Object?> get props => [draft];
}

class ProviderBackToListPressed extends ProviderEvent {
  const ProviderBackToListPressed();
}

class ProviderSaveRequested extends ProviderEvent {
  const ProviderSaveRequested({required this.draft, required this.creating});
  final ObjectProvider draft;
  final bool creating;

  @override
  List<Object?> get props => [draft, creating];
}

class ProviderDeleteRequested extends ProviderEvent {
  const ProviderDeleteRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}
