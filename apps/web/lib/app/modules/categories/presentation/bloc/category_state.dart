part of 'category_bloc.dart';

sealed class CategoryState extends Equatable {
  const CategoryState();

  @override
  List<Object?> get props => [];
}

/// Modo ÁRVORE (buildável) — itens ordenados por posit_level (a ordem já é
/// a da treeview); [kind] é a aba ativa.
class CategoryTreeState extends CategoryState {
  const CategoryTreeState({
    required this.kind,
    this.items = const [],
    this.loading = false,
  });

  final String kind;
  final List<CategoryEntity> items;
  final bool loading;

  @override
  List<Object?> get props => [kind, items, loading];
}

/// Modo formulário (buildável). [editing] null = inclusão (nível raiz ou
/// subnível de [initialParentId]).
class CategoryFormState extends CategoryState {
  const CategoryFormState({
    required this.kind,
    this.editing,
    this.initialParentId,
    this.initialParentName,
    this.saving = false,
  });

  final String kind;
  final CategoryEntity? editing;
  final int? initialParentId;
  final String? initialParentName;
  final bool saving;

  @override
  List<Object?> get props =>
      [kind, editing, initialParentId, initialParentName, saving];
}

/// Efeito one-shot de sucesso (listener-only, não buildável) — a página
/// entrega à ponte (showSuccessFeedback → SnackBar, R1).
class CategoryActionSuccess extends CategoryState {
  const CategoryActionSuccess(this.messageKey);

  /// Chave i18n ('register.saved' / 'register.deleted') — a ponte traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot de falha (listener-only, não buildável). Carrega o
/// [Failure] INTEIRO: a ponte deriva a natureza (validation × erro técnico
/// com supportRef — R7) e o fields[] ancora no campo do formulário (409
/// HAS_CHILDREN / TREE_CYCLE chegam com a mensagem da API).
class CategoryActionFailure extends CategoryState {
  const CategoryActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
