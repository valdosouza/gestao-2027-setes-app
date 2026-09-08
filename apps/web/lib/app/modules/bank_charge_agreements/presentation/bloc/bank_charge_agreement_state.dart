part of 'bank_charge_agreement_bloc.dart';

sealed class BankChargeAgreementState extends Equatable {
  const BankChargeAgreementState();

  @override
  List<Object?> get props => [];
}

/// Modo lista (buildável) — carteiras de cobrança da institution. Além dos
/// itens da página, o estado carrega filtro aplicado + metadados — a
/// página monta a barra de paginação da fábrica e reenvia [filter].
class BankChargeAgreementListState extends BankChargeAgreementState {
  const BankChargeAgreementListState({
    this.items = const [],
    this.loading = false,
    this.filter = '',
    this.page = 1,
    this.pageSize,
    this.total,
  });

  final List<BankChargeAgreementListItem> items;
  final bool loading;

  /// Filtro APLICADO (o mesmo usado na recarga pós-salvar/excluir).
  final String filter;
  final int page;

  /// null até a primeira resposta da API (barra só aparece com metadados).
  final int? pageSize;
  final int? total;

  @override
  List<Object?> get props => [items, loading, filter, page, pageSize, total];
}

/// Modo formulário (buildável). [editing] null = carteira nova.
class BankChargeAgreementFormState extends BankChargeAgreementState {
  const BankChargeAgreementFormState({this.editing, this.saving = false});
  final BankChargeAgreementFull? editing;
  final bool saving;

  @override
  List<Object?> get props => [editing, saving];
}

/// Efeito one-shot de sucesso (listener-only) — a página entrega à ponte
/// (showSuccessFeedback → SnackBar, R1).
class BankChargeAgreementActionSuccess extends BankChargeAgreementState {
  const BankChargeAgreementActionSuccess(this.messageKey);

  /// Chave i18n ('register.saved' / 'register.deleted') — a ponte traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot de falha (listener-only). Carrega o [Failure] INTEIRO:
/// a ponte deriva a natureza (validation × erro técnico — R7) e o fields[]
/// ancora no campo do formulário.
class BankChargeAgreementActionFailure extends BankChargeAgreementState {
  const BankChargeAgreementActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
