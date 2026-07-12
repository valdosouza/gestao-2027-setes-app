import 'package:flutter/material.dart';

/// Encapsula [DropdownButtonFormField] (decisão 11) — seleção de opção
/// única em domínio pequeno (ex.: filtro por módulo/grupo em listas).
/// Para FK/domínio grande use SetesLookupField (lista de apoio filtrável).
class SetesDropdown<T> extends StatelessWidget {
  const SetesDropdown({
    required this.label,
    required this.items,
    required this.onChanged,
    this.value,
    this.itemLabel,
    super.key,
  });

  final String label;
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;

  /// Texto exibido por item (default: toString).
  final String Function(T item)? itemLabel;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final item in items)
            DropdownMenuItem<T>(
              value: item,
              child: Text(
                itemLabel?.call(item) ?? '$item',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: onChanged,
      );
}
