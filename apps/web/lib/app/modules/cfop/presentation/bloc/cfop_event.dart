part of 'cfop_bloc.dart';

sealed class CfopEvent extends Equatable {
  const CfopEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a lista (também usado na abertura da página).
/// Paginação D3: [page] navega (filtro novo SEMPRE volta à página 1 na
/// tela); [pageSize] null mantém o tamanho corrente (1º load = config
/// page_size resolvida pela API — D4).
class CfopListRequested extends CfopEvent {
  const CfopListRequested(this.filter, {this.page = 1, this.pageSize});
  final String filter;
  final int page;
  final int? pageSize;

  @override
  List<Object?> get props => [filter, page, pageSize];
}

class CfopNewPressed extends CfopEvent {
  const CfopNewPressed();
}

class CfopEditPressed extends CfopEvent {
  const CfopEditPressed(this.cfop);
  final CfopEntity cfop;

  @override
  List<Object?> get props => [cfop];
}

/// Volta do formulário para a pesquisa SEM salvar.
class CfopBackToListPressed extends CfopEvent {
  const CfopBackToListPressed();
}

class CfopSaveRequested extends CfopEvent {
  const CfopSaveRequested({required this.cfop, required this.creating});
  final CfopEntity cfop;
  final bool creating;

  @override
  List<Object?> get props => [cfop, creating];
}

class CfopDeleteRequested extends CfopEvent {
  const CfopDeleteRequested(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}
