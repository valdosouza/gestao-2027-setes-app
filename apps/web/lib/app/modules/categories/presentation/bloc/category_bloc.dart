import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/category_entity.dart';
import '../../domain/usecase/category_delete.dart';
import '../../domain/usecase/category_getlist.dart';
import '../../domain/usecase/category_post.dart';
import '../../domain/usecase/category_put.dart';

part 'category_event.dart';
part 'category_state.dart';

/// Orquestra o cadastro em ÁRVORE de Categorias (porta do reg_category.pas;
/// decisões do Valdo 2026-07-18): duas árvores por kind (abas Produtos ×
/// Serviços), alterna árvore ↔ formulário; criar nasce como nível raiz
/// (FAB) ou subnível (ação no nó); mover de pai é da API (PUT com
/// parentId); excluir com subníveis devolve 409 (SnackBar).
class CategoryBloc extends Bloc<CategoryEvent, CategoryState> {
  CategoryBloc({
    required this.getlist,
    required this.post,
    required this.put,
    required this.delete,
  }) : super(const CategoryTreeState(kind: 'P', loading: true)) {
    on<CategoryTreeRequested>(_onTreeRequested);
    on<CategoryNewPressed>(_onNewPressed);
    on<CategoryEditPressed>((event, emit) => emit(CategoryFormState(
        kind: event.category.kind, editing: event.category)));
    on<CategoryBackToTreePressed>((event, emit) => _reload(emit));
    on<CategorySaveRequested>(_onSaveRequested);
    on<CategoryDeleteRequested>(_onDeleteRequested);
  }

  final CategoryGetlist getlist;
  final CategoryPost post;
  final CategoryPut put;
  final CategoryDelete delete;

  /// Árvore (kind) ativa — recarga após salvar/excluir/voltar e troca de aba.
  String _kind = 'P';

  Future<void> _onTreeRequested(
      CategoryTreeRequested event, Emitter<CategoryState> emit) async {
    _kind = event.kind;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<CategoryState> emit) async {
    emit(CategoryTreeState(kind: _kind, loading: true));
    final result = await getlist(_kind);
    result.fold(
      (failure) {
        emit(CategoryActionFailure(failure.message));
        emit(CategoryTreeState(kind: _kind));
      },
      (items) => emit(CategoryTreeState(kind: _kind, items: items)),
    );
  }

  /// Novo NÍVEL raiz (parent null — FAB) ou SUBNÍVEL (ação no nó).
  void _onNewPressed(CategoryNewPressed event, Emitter<CategoryState> emit) {
    emit(CategoryFormState(
      kind: _kind,
      initialParentId: event.parent?.id,
      initialParentName: event.parent?.description,
    ));
  }

  Future<void> _onSaveRequested(
      CategorySaveRequested event, Emitter<CategoryState> emit) async {
    emit(CategoryFormState(
        kind: event.category.kind,
        editing: event.creating ? null : event.category,
        saving: true));
    final result = event.creating
        ? await post(event.category)
        : await put(event.category);
    await result.fold(
      (failure) async {
        emit(CategoryActionFailure(failure.message));
        emit(CategoryFormState(
            kind: event.category.kind,
            editing: event.creating ? null : event.category));
      },
      (_) async {
        emit(const CategoryActionSuccess('register.saved'));
        await _reload(emit);
      },
    );
  }

  Future<void> _onDeleteRequested(
      CategoryDeleteRequested event, Emitter<CategoryState> emit) async {
    final result = await delete(event.id);
    await result.fold(
      // 409 = possui subníveis (decisão: bloquear — mensagem da API)
      (failure) async => emit(CategoryActionFailure(failure.message)),
      (_) async {
        emit(const CategoryActionSuccess('register.deleted'));
        await _reload(emit);
      },
    );
  }
}
