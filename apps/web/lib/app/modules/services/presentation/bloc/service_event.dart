part of 'service_bloc.dart';

sealed class ServiceEvent extends Equatable {
  const ServiceEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a lista (também usado na abertura da página). Filtro
/// REMOTO (?filter= por descrição/identificador). Paginação: [page]
/// navega (filtro novo SEMPRE volta à página 1 na tela); [pageSize] null
/// mantém o tamanho corrente (1º load = config page_size da API).
class ServiceListRequested extends ServiceEvent {
  const ServiceListRequested(this.filter, {this.page = 1, this.pageSize});
  final String filter;
  final int page;
  final int? pageSize;

  @override
  List<Object?> get props => [filter, page, pageSize];
}

/// Novo serviço — o bloc carrega as tabelas de preço vivas antes de emitir
/// o form (grade da aba Preços nasce com priceTag null — D4/D7).
class ServiceNewPressed extends ServiceEvent {
  const ServiceNewPressed();
}

/// Abre a edição — o bloc carrega o serviço COMPLETO (GET /:id, já com a
/// grade de preços) antes de emitir o form.
class ServiceEditPressed extends ServiceEvent {
  const ServiceEditPressed(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}

/// Volta do formulário para a lista SEM salvar.
class ServiceBackToListPressed extends ServiceEvent {
  const ServiceBackToListPressed();
}

/// Salvar: [editingId] null = POST; preenchido = PUT. [input] já validado
/// pela página (a API revalida via Zod — 400 {error, fields[]}).
class ServiceSaveRequested extends ServiceEvent {
  const ServiceSaveRequested({this.editingId, required this.input});

  final int? editingId;
  final ServiceInput input;

  @override
  List<Object?> get props => [editingId, input];
}

class ServiceDeleteRequested extends ServiceEvent {
  const ServiceDeleteRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}
