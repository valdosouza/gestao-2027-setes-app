part of 'module_bloc.dart';

sealed class ModuleEvent extends Equatable {
  const ModuleEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a lista (também usado na abertura da página).
/// Paginação D3: [page] navega (filtro novo SEMPRE volta à página 1 na
/// tela); [pageSize] null mantém o tamanho corrente (1º load = config
/// page_size resolvida pela API — D4).
class ModuleListRequested extends ModuleEvent {
  const ModuleListRequested(this.filter, {this.page = 1, this.pageSize});
  final String filter;
  final int page;
  final int? pageSize;

  @override
  List<Object?> get props => [filter, page, pageSize];
}

class ModuleNewPressed extends ModuleEvent {
  const ModuleNewPressed();
}

class ModuleEditPressed extends ModuleEvent {
  const ModuleEditPressed(this.module);
  final ModuleEntity module;

  @override
  List<Object?> get props => [module];
}

/// Volta do formulário para a pesquisa SEM salvar.
class ModuleBackToListPressed extends ModuleEvent {
  const ModuleBackToListPressed();
}

class ModuleSaveRequested extends ModuleEvent {
  const ModuleSaveRequested({required this.module, required this.creating});
  final ModuleEntity module;
  final bool creating;

  @override
  List<Object?> get props => [module, creating];
}

class ModuleDeleteRequested extends ModuleEvent {
  const ModuleDeleteRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}
