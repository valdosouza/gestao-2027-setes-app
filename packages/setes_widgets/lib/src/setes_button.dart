import 'package:flutter/material.dart';

import 'setes_circular_progress_indicator.dart';
import 'setes_text.dart';

enum SetesButtonKind { primary, secondary, text }

/// Encapsula os botões do Material (decisão 11).
class SetesButton extends StatelessWidget {
  const SetesButton({
    required this.label,
    required this.onPressed,
    this.kind = SetesButtonKind.primary,
    this.loading = false,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final SetesButtonKind kind;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Widget child = loading
        ? const SizedBox(height: 20, width: 20, child: SetesCircularProgressIndicator(strokeWidth: 2))
        : SetesText(label);
    final VoidCallback? action = loading ? null : onPressed;

    switch (kind) {
      case SetesButtonKind.primary:
        return icon != null
            ? ElevatedButton.icon(onPressed: action, icon: Icon(icon), label: child)
            : ElevatedButton(onPressed: action, child: child);
      case SetesButtonKind.secondary:
        return OutlinedButton(onPressed: action, child: child);
      case SetesButtonKind.text:
        return TextButton(onPressed: action, child: child);
    }
  }
}
