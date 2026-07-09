import 'package:flutter/material.dart';

/// Encapsula [IconButton] (decisão 11).
class SetesIconButton extends StatelessWidget {
  const SetesIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) =>
      IconButton(icon: Icon(icon), onPressed: onPressed, tooltip: tooltip);
}
