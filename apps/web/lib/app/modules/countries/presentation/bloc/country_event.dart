part of 'country_bloc.dart';

sealed class CountryEvent extends Equatable {
  const CountryEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a lista (também usado na abertura da página).
/// Paginação D3: [page] navega (filtro novo SEMPRE volta à página 1 na
/// tela); [pageSize] null mantém o tamanho corrente (1º load = config
/// page_size resolvida pela API — D4).
class CountryListRequested extends CountryEvent {
  const CountryListRequested(this.filter, {this.page = 1, this.pageSize});
  final String filter;
  final int page;
  final int? pageSize;

  @override
  List<Object?> get props => [filter, page, pageSize];
}

class CountryNewPressed extends CountryEvent {
  const CountryNewPressed();
}

class CountryEditPressed extends CountryEvent {
  const CountryEditPressed(this.country);
  final CountryEntity country;

  @override
  List<Object?> get props => [country];
}

/// Volta do formulário para a pesquisa SEM salvar.
class CountryBackToListPressed extends CountryEvent {
  const CountryBackToListPressed();
}

class CountrySaveRequested extends CountryEvent {
  const CountrySaveRequested({required this.country, required this.creating});
  final CountryEntity country;
  final bool creating;

  @override
  List<Object?> get props => [country, creating];
}

class CountryDeleteRequested extends CountryEvent {
  const CountryDeleteRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}
