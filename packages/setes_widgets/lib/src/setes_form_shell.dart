import 'package:flutter/material.dart';

/// Casca padrão de formulário de cadastro (contrato visual do
/// customer_register — skill criar-formulario-cadastro.md):
/// Scaffold aninhado com AppBar própria — voltar (`arrow_back_ios_rounded`,
/// SEM salvar), título já traduzido, salvar (`Icons.check`) e excluir
/// (`delete_outline`) quando aplicável.
///
/// Cores SEMPRE do Theme (tema por institution — decisão 16): nenhuma cor
/// hardcoded aqui.
class SetesFormShell extends StatelessWidget {
  const SetesFormShell({
    required this.title,
    required this.onBack,
    required this.child,
    this.onSave,
    this.onDelete,
    this.saving = false,
    this.actions,
    super.key,
  });

  /// Título já traduzido — SIMPLES, só a entidade (ex.: "País").
  final String title;

  /// Volta para a pesquisa SEM salvar.
  final VoidCallback onBack;

  /// null = usuário sem privilégio de salvar (decisão 21) — ícone some.
  final VoidCallback? onSave;

  /// null = registro novo ou sem privilégio de excluir — ícone some.
  final VoidCallback? onDelete;

  /// Desabilita as ações enquanto uma operação está em andamento.
  final bool saving;

  /// Corpo do formulário (Form + campos).
  final Widget child;

  /// Ações extras no AppBar, ANTES de excluir/salvar (ex.: engrenagem do
  /// Framework de Configurações). null = sem ações extras.
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: saving ? null : onBack,
          ),
          title: Text(title),
          actions: [
            ...?actions,
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: saving ? null : onDelete,
              ),
            if (onSave != null)
              IconButton(
                icon: const Icon(Icons.check, size: 30),
                onPressed: saving ? null : onSave,
              ),
          ],
        ),
        body: child,
      );
}
