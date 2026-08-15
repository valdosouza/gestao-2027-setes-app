import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/module_entity.dart';
import '../../domain/usecase/module_delete.dart';
import '../../domain/usecase/module_getlist.dart';
import '../../domain/usecase/module_interface_options.dart';
import '../../domain/usecase/module_post.dart';
import '../../domain/usecase/module_put.dart';

part 'module_event.dart';
part 'module_state.dart';

/// Orquestra o CRUD dos Módulos de Menu do cliente (interface 'modules',
/// camada 2 do menu — prompt_modulo_menus.md D1–D4): alterna pesquisa ↔
/// formulário via usecases (ARQUITETURA_MODULOS.md — a fábrica Register* é
/// apresentação pura; sucesso/erro viram estados one-shot que a página
/// entrega à PONTE de feedback). Ao abrir o form o bloc carrega as
/// interfaces ELEGÍVEIS (picker + rótulos da seção "Telas do módulo").
class ModuleBloc extends Bloc<ModuleEvent, ModuleState> {
  ModuleBloc({
    required this.getlist,
    required this.interfaceOptions,
    required this.post,
    required this.put,
    required this.delete,
  }) : super(const ModuleListState(loading: true)) {
    on<ModuleListRequested>(_onListRequested);
    on<ModuleNewPressed>((event, emit) => _openForm(emit, null));
    on<ModuleEditPressed>((event, emit) => _openForm(emit, event.module));
    on<ModuleBackToListPressed>((event, emit) => _reload(emit));
    on<ModuleSaveRequested>(_onSaveRequested);
    on<ModuleDeleteRequested>(_onDeleteRequested);
  }

  final ModuleGetlist getlist;
  final ModuleInterfaceOptions interfaceOptions;
  final ModulePost post;
  final ModulePut put;
  final ModuleDelete delete;

  /// Últimos filtro/página/tamanho aplicados — recarga após salvar/excluir/
  /// voltar devolve o usuário exatamente onde estava (paginação, critério 6).
  String _filter = '';
  int _page = 1;
  int? _pageSize;

  /// Cache das elegíveis DENTRO da sessão do bloc (o contrato muda pouco);
  /// falha na carga vira one-shot e o form abre com picker vazio.
  List<ModuleInterfaceOption>? _options;

  Future<void> _onListRequested(
      ModuleListRequested event, Emitter<ModuleState> emit) async {
    _filter = event.filter;
    _page = event.page;
    _pageSize = event.pageSize ?? _pageSize;
    await _reload(emit);
  }

  Future<void> _reload(Emitter<ModuleState> emit) async {
    emit(const ModuleListState(loading: true));
    final result = await getlist(_filter, page: _page, pageSize: _pageSize);
    await result.fold(
      (failure) async {
        emit(ModuleActionFailure(failure));
        emit(const ModuleListState());
      },
      (paged) async {
        // Página esvaziou (ex.: exclusão do último item) → recua para a
        // última página existente em vez de mostrar lista vazia.
        if (paged.items.isEmpty && paged.total > 0 && paged.page > 1) {
          _page = paged.pageCount;
          return _reload(emit);
        }
        // A resposta é a fonte da verdade (clamp/config da API — D4/D5).
        _page = paged.page;
        _pageSize = paged.pageSize;
        emit(ModuleListState(
          items: paged.items,
          filter: _filter,
          page: paged.page,
          pageSize: paged.pageSize,
          total: paged.total,
        ));
      },
    );
  }

  /// Abre o formulário carregando as interfaces elegíveis (uma vez por
  /// sessão do bloc). Falha na carga = one-shot + form com picker vazio.
  Future<void> _openForm(
      Emitter<ModuleState> emit, ModuleEntity? editing) async {
    if (_options == null) {
      final result = await interfaceOptions();
      result.fold(
        (failure) => emit(ModuleActionFailure(failure)),
        (options) => _options = options,
      );
    }
    emit(ModuleFormState(editing: editing, options: _options ?? const []));
  }

  Future<void> _onSaveRequested(
      ModuleSaveRequested event, Emitter<ModuleState> emit) async {
    final options = _options ?? const <ModuleInterfaceOption>[];
    emit(ModuleFormState(
        editing: event.creating ? null : event.module,
        saving: true,
        options: options));
    final result = event.creating
        ? await post(event.module)
        : await put(event.module);
    await result.fold(
      (failure) async {
        emit(ModuleActionFailure(failure));
        emit(ModuleFormState(
            editing: event.creating ? null : event.module,
            options: options));
      },
      (_) async {
        emit(const ModuleActionSuccess('register.saved'));
        await _reload(emit);
      },
    );
  }

  Future<void> _onDeleteRequested(
      ModuleDeleteRequested event, Emitter<ModuleState> emit) async {
    final result = await delete(event.id);
    await result.fold(
      (failure) async => emit(ModuleActionFailure(failure)),
      (_) async {
        emit(const ModuleActionSuccess('register.deleted'));
        await _reload(emit);
      },
    );
  }
}
