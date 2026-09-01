part of 'establishment_bloc.dart';

abstract class EstablishmentState extends Equatable {
  const EstablishmentState();

  @override
  List<Object?> get props => [];
}

/// Estado BUILDÁVEL único (não há lista): [loading] = carregando o GET
/// inicial; [draft] null + !loading = falha no GET (tela de erro com
/// retry); [saving] = PUT em andamento (desabilita as ações do shell).
class EstablishmentPanelState extends EstablishmentState {
  const EstablishmentPanelState({
    this.loading = false,
    this.saving = false,
    this.draft,
  });

  final bool loading;
  final bool saving;
  final ObjectEstablishment? draft;

  @override
  List<Object?> get props => [loading, saving, draft];
}

/// One-shot para a ponte de feedback (Framework de Mensagens) — sucesso =
/// SnackBar (R1).
class EstablishmentActionSuccess extends EstablishmentState {
  const EstablishmentActionSuccess(this.messageKey);

  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// One-shot de falha — a página decide dialog genérico ou ancorar
/// fields[] no campo (showServerFieldError).
class EstablishmentActionFailure extends EstablishmentState {
  const EstablishmentActionFailure(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
