part of 'country_bloc.dart';

sealed class CountryEvent extends Equatable {
  const CountryEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a lista (também usado na abertura da página).
class CountryListRequested extends CountryEvent {
  const CountryListRequested(this.filter);
  final String filter;

  @override
  List<Object?> get props => [filter];
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
