import 'package:flutter/material.dart';

/// Nó da árvore genérica do design system (cadastros RECURSIVOS —
/// 1º caso: Categorias de produtos/serviços, porta do TTreeView do Delphi).
class SetesTreeNode<T> {
  const SetesTreeNode({
    required this.id,
    required this.label,
    required this.data,
    this.subtitle,
    this.children = const [],
  });

  final int id;
  final String label;
  final String? subtitle;
  final T data;
  final List<SetesTreeNode<T>> children;
}

/// Treeview do design system: expand/collapse por nó, clique na linha
/// (edição) e ação opcional de "novo subnível" por nó. Recebe os nós JÁ
/// montados (a hierarquia é do domínio do módulo); cores sempre do Theme.
class SetesTreeView<T> extends StatefulWidget {
  const SetesTreeView({
    required this.nodes,
    required this.onTap,
    this.onAddChild,
    this.addChildTooltip,
    this.emptyText = '',
    super.key,
  });

  final List<SetesTreeNode<T>> nodes;
  final void Function(T data) onTap;

  /// Ação "novo subnível" (ícone + na linha). null = sem a ação.
  final void Function(T data)? onAddChild;
  final String? addChildTooltip;
  final String emptyText;

  @override
  State<SetesTreeView<T>> createState() => _SetesTreeViewState<T>();
}

class _SetesTreeViewState<T> extends State<SetesTreeView<T>> {
  /// Nós RECOLHIDOS (padrão = tudo expandido — árvores de cadastro são
  /// pequenas; o estado sobrevive a rebuilds da lista).
  final Set<int> _collapsed = {};

  Widget _buildNode(SetesTreeNode<T> node, int depth) {
    final hasChildren = node.children.isNotEmpty;
    final collapsed = _collapsed.contains(node.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => widget.onTap(node.data),
          child: Padding(
            padding: EdgeInsets.only(left: 16.0 * depth, top: 2, bottom: 2),
            child: Row(
              children: [
                hasChildren
                    ? IconButton(
                        icon: Icon(collapsed
                            ? Icons.chevron_right
                            : Icons.expand_more),
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: () => setState(() {
                          collapsed
                              ? _collapsed.remove(node.id)
                              : _collapsed.add(node.id);
                        }),
                      )
                    : const SizedBox(width: 32),
                Icon(
                  hasChildren ? Icons.folder_outlined : Icons.label_outline,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(node.label),
                      if (node.subtitle != null)
                        Text(node.subtitle!,
                            style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                if (widget.onAddChild != null)
                  IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    tooltip: widget.addChildTooltip,
                    onPressed: () => widget.onAddChild!(node.data),
                  ),
              ],
            ),
          ),
        ),
        if (hasChildren && !collapsed)
          for (final child in node.children) _buildNode(child, depth + 1),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.nodes.isEmpty) {
      return Center(child: Text(widget.emptyText));
    }
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [for (final node in widget.nodes) _buildNode(node, 0)],
    );
  }
}
