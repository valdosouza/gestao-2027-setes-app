part of 'category_bloc.dart';

sealed class CategoryEvent extends Equatable {
  const CategoryEvent();

  @override
  List<Object?> get props => [];
}

/// Carrega a ÁRVORE do kind ('P' produtos / 'S' serviços — troca de aba).
class CategoryTreeRequested extends CategoryEvent {
  const CategoryTreeRequested(this.kind);
  final String kind;

  @override
  List<Object?> get props => [kind];
}

/// Novo nível raiz ([parent] null — FAB) ou subnível do nó ([parent]).
class CategoryNewPressed extends CategoryEvent {
  const CategoryNewPressed({this.parent});
  final CategoryEntity? parent;

  @override
  List<Object?> get props => [parent];
}

class CategoryEditPressed extends CategoryEvent {
  const CategoryEditPressed(this.category);
  final CategoryEntity category;

  @override
  List<Object?> get props => [category];
}

/// Volta do formulário para a árvore SEM salvar.
class CategoryBackToTreePressed extends CategoryEvent {
  const CategoryBackToTreePressed();
}

class CategorySaveRequested extends CategoryEvent {
  const CategorySaveRequested({required this.category, required this.creating});
  final CategoryEntity category;
  final bool creating;

  @override
  List<Object?> get props => [category, creating];
}

class CategoryDeleteRequested extends CategoryEvent {
  const CategoryDeleteRequested(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}
