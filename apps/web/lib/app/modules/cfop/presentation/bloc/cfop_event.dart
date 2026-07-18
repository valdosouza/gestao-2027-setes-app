part of 'cfop_bloc.dart';

sealed class CfopEvent extends Equatable {
  const CfopEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega/filtra a lista (também usado na abertura da página).
class CfopListRequested extends CfopEvent {
  const CfopListRequested(this.filter);
  final String filter;

  @override
  List<Object?> get props => [filter];
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
