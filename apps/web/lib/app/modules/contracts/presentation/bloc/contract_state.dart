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

/// Efeito one-shot para SnackBar de sucesso (listener-only, não buildável).
class ContractActionSuccess extends ContractState {
  const ContractActionSuccess(this.messageKey);

  /// Chave i18n — a página traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot para SnackBar de erro (listener-only, não buildável).
class ContractActionFailure extends ContractState {
  const ContractActionFailure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
