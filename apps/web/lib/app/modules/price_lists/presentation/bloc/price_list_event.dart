part of 'price_list_bloc.dart';

sealed class PriceListEvent extends Equatable {
  const PriceListEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a lista (também usado na abertura da página). Filtro
/// REMOTO (?filter= por descrição). Paginação: [page] navega (filtro novo
/// SEMPRE volta à página 1 na tela); [pageSize] null mantém o tamanho
/// corrente (1º load = config page_size da API).
class PriceListListRequested extends PriceListEvent {
  const PriceListListRequested(this.filter, {this.page = 1, this.pageSize});
  final String filter;
  final int page;
  final int? pageSize;

  @override
  List<Object?> get props => [filter, page, pageSize];
}

class PriceListNewPressed extends PriceListEvent {
  const PriceListNewPressed();
}

/// Abre a edição — o bloc recarrega a tabela (GET /:id) antes de emitir o
/// form (fonte da verdade é a API, não a linha da lista).
class PriceListEditPressed extends PriceListEvent {
  const PriceListEditPressed(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}

/// Volta do formulário para a lista SEM salvar.
class PriceListBackToListPressed extends PriceListEvent {
  const PriceListBackToListPressed();
}

/// Salvar: [editingId] null = POST; preenchido = PUT. [input] já validado
/// pela página (a API revalida via Zod — 400 {error, fields[]}).
class PriceListSaveRequested extends PriceListEvent {
  const PriceListSaveRequested({this.editingId, required this.input});

  final int? editingId;
  final PriceListInput input;

  @override
  List<Object?> get props => [editingId, input];
}

class PriceListDeleteRequested extends PriceListEvent {
  const PriceListDeleteRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}
