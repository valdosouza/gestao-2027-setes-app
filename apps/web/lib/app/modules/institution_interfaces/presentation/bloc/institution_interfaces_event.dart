part of 'institution_interfaces_bloc.dart';

sealed class InstitutionInterfacesEvent extends Equatable {
  const InstitutionInterfacesEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a lista (também na abertura). Filtro novo volta à página 1
/// na tela; [pageSize] null mantém o tamanho corrente.
class InstitutionInterfacesListRequested extends InstitutionInterfacesEvent {
  const InstitutionInterfacesListRequested(this.filter, {this.page = 1, this.pageSize});
  final String filter;
  final int page;
  final int? pageSize;

  @override
  List<Object?> get props => [filter, page, pageSize];
}

/// Abre as interfaces de um estabelecimento.
class InstitutionInterfacesOpened extends InstitutionInterfacesEvent {
  const InstitutionInterfacesOpened(this.client);
  final ClientInstitutionEntity client;

  @override
  List<Object?> get props => [client.id];
}

/// Volta do detalhe para a lista.
class InstitutionInterfacesBackToList extends InstitutionInterfacesEvent {
  const InstitutionInterfacesBackToList();
}
