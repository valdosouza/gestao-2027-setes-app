part of 'customer_bloc.dart';

sealed class CustomerBlocState extends Equatable {
  const CustomerBlocState();

  @override
  List<Object?> get props => [];
}

/// Modo pesquisa (buildável).
class CustomerListState extends CustomerBlocState {
  const CustomerListState({this.items = const [], this.loading = false});
  final List<CustomerListItem> items;
  final bool loading;

  @override
  List<Object?> get props => [items, loading];
}

/// Modo formulário (buildável). O [draft] é o ObjectCustomer INTEIRO —
/// as abas editam fatias via CustomerDraftChanged.
class CustomerFormState extends CustomerBlocState {
  const CustomerFormState({
    required this.draft,
    required this.creating,
    this.saving = false,
  });

  final ObjectCustomer draft;
  final bool creating;
  final bool saving;

  @override
  List<Object?> get props => [draft, creating, saving];
}

/// Efeito one-shot de sucesso (listener-only, não buildável) — a página
/// entrega à ponte (showSuccessFeedback → SnackBar, R1).
class CustomerActionSuccess extends CustomerBlocState {
  const CustomerActionSuccess(this.messageKey);

  /// Chave i18n ('register.saved' / 'forms.customer.reusedEntity' /
  /// 'register.deleted') — a ponte traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot de falha (listener-only, não buildável). Carrega o
/// [Failure] INTEIRO: a ponte deriva a natureza (validation × erro técnico
/// com supportRef — R7) e o fields[] ancora no campo da aba certa.
class CustomerActionFailure extends CustomerBlocState {
  const CustomerActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// Efeito one-shot do 409 de papel duplicado (Fase 3, decisão 2): a entity
/// já é cliente desta institution — a página oferece abrir [existingId]
/// em edição (dialog).
class CustomerDuplicateRole extends CustomerBlocState {
  const CustomerDuplicateRole(this.existingId);
  final int existingId;

  @override
  List<Object?> get props => [existingId];
}
