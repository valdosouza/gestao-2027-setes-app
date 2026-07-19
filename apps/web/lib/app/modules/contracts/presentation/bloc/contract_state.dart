part of 'contract_bloc.dart';

sealed class ContractState extends Equatable {
  const ContractState();

  @override
  List<Object?> get props => [];
}

/// Modo lista (buildável) — contratos da institution.
class ContractListState extends ContractState {
  const ContractListState({this.items = const [], this.loading = false});
  final List<ContractListItem> items;
  final bool loading;

  @override
  List<Object?> get props => [items, loading];
}

/// Modo formulário (buildável). [editing] null = contrato novo.
class ContractFormState extends ContractState {
  const ContractFormState({this.editing, this.saving = false});
  final ContractFull? editing;
  final bool saving;

  @override
  List<Object?> get props => [editing, saving];
}

/// Efeito one-shot de sucesso (listener-only, não buildável) — a página
/// entrega à ponte (showSuccessFeedback → SnackBar, R1).
class ContractActionSuccess extends ContractState {
  const ContractActionSuccess(this.messageKey);

  /// Chave i18n ('register.saved' / 'register.deleted') — a ponte traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot de falha (listener-only, não buildável). Carrega o
/// [Failure] INTEIRO: a ponte deriva a natureza (validation × erro técnico
/// com supportRef — R7) e o fields[] ancora no campo do formulário.
class ContractActionFailure extends ContractState {
  const ContractActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
