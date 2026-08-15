part of 'module_bloc.dart';

sealed class ModuleState extends Equatable {
  const ModuleState();

  @override
  List<Object?> get props => [];
}

/// Modo pesquisa (buildável). Paginação D3: além dos itens da página, o
/// estado carrega filtro aplicado + metadados — a página monta a barra da
/// fábrica e reenvia [filter] ao navegar.
class ModuleListState extends ModuleState {
  const ModuleListState({
    this.items = const [],
    this.loading = false,
    this.filter = '',
    this.page = 1,
    this.pageSize,
    this.total,
  });

  final List<ModuleEntity> items;
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

/// Modo formulário (buildável). [editing] null = inclusão. [options] =
/// interfaces ELEGÍVEIS ao vínculo (picker + rótulos da seção de telas),
/// carregadas pelo bloc na abertura do form.
class ModuleFormState extends ModuleState {
  const ModuleFormState({
    this.editing,
    this.saving = false,
    this.options = const [],
  });

  final ModuleEntity? editing;
  final bool saving;
  final List<ModuleInterfaceOption> options;

  @override
  List<Object?> get props => [editing, saving, options];
}

/// Efeito one-shot de sucesso (listener-only, não buildável) — a página
/// entrega à ponte (showSuccessFeedback → SnackBar, R1).
class ModuleActionSuccess extends ModuleState {
  const ModuleActionSuccess(this.messageKey);

  /// Chave i18n ('register.saved' / 'register.deleted') — a ponte traduz.
  final String messageKey;

  @override
  List<Object?> get props => [messageKey];
}

/// Efeito one-shot de falha (listener-only, não buildável). Carrega o
/// [Failure] INTEIRO: a ponte deriva a natureza (validation × erro técnico
/// com supportRef — R7) e o fields[] ancora na seção/campo do formulário.
class ModuleActionFailure extends ModuleState {
  const ModuleActionFailure(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
