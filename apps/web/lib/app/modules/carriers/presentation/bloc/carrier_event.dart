part of 'carrier_bloc.dart';

sealed class CarrierEvent extends Equatable {
  const CarrierEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a pesquisa (também usado na abertura da página).
/// Paginação D3: [page] navega (filtro novo SEMPRE volta à página 1 na
/// tela); [pageSize] null mantém o tamanho corrente (1º load = config
/// page_size resolvida pela API — D4).
class CarrierListRequested extends CarrierEvent {
  const CarrierListRequested(this.filter, {this.page = 1, this.pageSize});
  final String filter;
  final int page;
  final int? pageSize;

  @override
  List<Object?> get props => [filter, page, pageSize];
}

class CarrierNewPressed extends CarrierEvent {
  const CarrierNewPressed();
}

/// Abre a edição: o bloc busca o objeto COMPLETO via GET :id. Também usado
/// pelo dialog do 409 de papel duplicado (abrir o registro existente).
class CarrierEditPressed extends CarrierEvent {
  const CarrierEditPressed(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}

/// Uma aba editou uma fatia do draft.
class CarrierDraftChanged extends CarrierEvent {
  const CarrierDraftChanged(this.draft);
  final ObjectCarrier draft;

  @override
  List<Object?> get props => [draft];
}

class CarrierBackToListPressed extends CarrierEvent {
  const CarrierBackToListPressed();
}

class CarrierSaveRequested extends CarrierEvent {
  const CarrierSaveRequested({required this.draft, required this.creating});
  final ObjectCarrier draft;
  final bool creating;

  @override
  List<Object?> get props => [draft, creating];
}

class CarrierDeleteRequested extends CarrierEvent {
  const CarrierDeleteRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}
