import 'package:flutter/material.dart';

/// Encapsula [IconButton] (decisão 11).
class SetesIconButton extends StatelessWidget {
  const SetesIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  /// Cor do ícone quando o fundo não é o da tela (ex.: o cabeçalho do menu
  /// lateral, na cor da barra). null = a do tema.
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      IconButton(icon: Icon(icon), onPressed: onPressed, tooltip: tooltip, color: color);
}
