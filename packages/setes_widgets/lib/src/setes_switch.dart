import 'package:flutter/material.dart';

/// Switch com rótulo do design system (Framework de Configurações,
/// decisão 6: kind Boolean renderiza switch — checkbox continua sendo o
/// SetesCheckbox). Cores sempre do Theme.
class SetesSwitch extends StatelessWidget {
  const SetesSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
    super.key,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => SwitchListTile(
        title: Text(label),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        value: value,
        onChanged: enabled ? onChanged : null,
        contentPadding: EdgeInsets.zero,
        dense: true,
      );
}
