part of 'institution_interfaces_bloc.dart';

sealed class InstitutionInterfacesState extends Equatable {
  const InstitutionInterfacesState();

  @override
  List<Object?> get props => [];
}

/// Lista paginada de estabelecimentos (buildável).
class InstitutionInterfacesListState extends InstitutionInterfacesState {
  const InstitutionInterfacesListState({
    this.items = const [],
    this.loading = false,
    this.filter = '',
    this.page = 1,
    this.pageSize,
    this.total,
  });

  final List<ClientInstitutionEntity> items;
  final bool loading;
  final String filter;
  final int page;
  final int? pageSize;
  final int? total;

  @override
  List<Object?> get props => [items.map((e) => e.id).toList(), loading, filter, page, pageSize, total];
}

/// Interfaces do estabelecimento aberto (buildável).
class InstitutionInterfacesDetailState extends InstitutionInterfacesState {
  const InstitutionInterfacesDetailState(this.client);
  final ClientInstitutionEntity client;

  @override
  List<Object?> get props => [client.id];
}

/// Falha one-shot (listener-only) — a ponte deriva a natureza (R7).
class InstitutionInterfacesActionFailure extends InstitutionInterfacesState {
  const InstitutionInterfacesActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
