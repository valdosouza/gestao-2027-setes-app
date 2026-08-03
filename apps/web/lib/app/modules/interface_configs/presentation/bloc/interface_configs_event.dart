part of 'interface_configs_bloc.dart';

sealed class InterfaceConfigsEvent extends Equatable {
  const InterfaceConfigsEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a vitrine (também usado na abertura da página).
/// Paginação D3: [page] navega (filtro novo SEMPRE volta à página 1 na
/// tela); [pageSize] null mantém o tamanho corrente (1º load = config
/// page_size resolvida pela API — D4).
class InterfaceConfigsVitrineRequested extends InterfaceConfigsEvent {
  const InterfaceConfigsVitrineRequested(this.filter,
      {this.page = 1, this.pageSize});
  final String filter;
  final int page;
  final int? pageSize;

  @override
  List<Object?> get props => [filter, page, pageSize];
}

/// Abre a lista de configurações de uma interface ADQUIRIDA.
class InterfaceConfigsInterfaceOpened extends InterfaceConfigsEvent {
  const InterfaceConfigsInterfaceOpened(this.iface);
  final InterfaceVitrineEntity iface;

  @override
  List<Object?> get props => [iface];
}

/// Atalho da engrenagem (decisão 11): abre já filtrado pela CHAVE do módulo.
class InterfaceConfigsOpenByKey extends InterfaceConfigsEvent {
  const InterfaceConfigsOpenByKey(this.moduleKey);
  final String moduleKey;

  @override
  List<Object?> get props => [moduleKey];
}

/// Volta da lista de configurações para a vitrine.
class InterfaceConfigsBackToVitrine extends InterfaceConfigsEvent {
  const InterfaceConfigsBackToVitrine();
}

/// Salva o valor de UMA configuração. [content] null = volta a herdar;
/// [asUser] true = override pessoal (scope 'U'), false = institution (admin).
class InterfaceConfigsValueSaveRequested extends InterfaceConfigsEvent {
  const InterfaceConfigsValueSaveRequested({
    required this.name,
    required this.content,
    required this.asUser,
  });

  final String name;
  final String? content;
  final bool asUser;

  @override
  List<Object?> get props => [name, content, asUser];
}
