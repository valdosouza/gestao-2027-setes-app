part of 'city_bloc.dart';

sealed class CityEvent extends Equatable {
  const CityEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a lista (também usado na abertura da página).
class CityListRequested extends CityEvent {
  const CityListRequested(this.filter);
  final String filter;

  @override
  List<Object?> get props => [filter];
}

class CityNewPressed extends CityEvent {
  const CityNewPressed();
}

class CityEditPressed extends CityEvent {
  const CityEditPressed(this.city);
  final CityEntity city;

  @override
  List<Object?> get props => [city];
}

/// Volta do formulário para a pesquisa SEM salvar.
class CityBackToListPressed extends CityEvent {
  const CityBackToListPressed();
}

class CitySaveRequested extends CityEvent {
  const CitySaveRequested({required this.city, required this.creating});
  final CityEntity city;
  final bool creating;

  @override
  List<Object?> get props => [city, creating];
}

class CityDeleteRequested extends CityEvent {
  const CityDeleteRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}
