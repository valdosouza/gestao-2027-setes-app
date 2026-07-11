import 'package:flutter/material.dart';

/// Encapsula [TextFormField] (decisão 11).
///
/// Tabulação (feedback do Valdo 2026-07-11): Tab percorre só os campos
/// EDITÁVEIS, na ordem declarada — readOnly e botões de sufixo ficam fora
/// da sequência (continuam acionáveis por clique).
class SetesTextField extends StatelessWidget {
  const SetesTextField({
    required this.label,
    this.controller,
    this.obscureText = false,
    this.readOnly = false,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixPressed,
    this.hint,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final bool obscureText;

  /// Campo somente leitura (ex.: código imutável na edição, campos de lookup).
  /// Fica FORA da sequência de tabulação (foco só por clique).
  final bool readOnly;

  /// Foco inicial ao abrir a tela (primeiro campo editável do form).
  final bool autofocus;
  final TextInputType? keyboardType;

  /// next nos campos intermediários, done no último (Enter avança no mobile).
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;
  final IconData? prefixIcon;

  /// Ícone à direita; com [onSuffixPressed] vira botão (ex.: Icons.search).
  /// O botão não entra na sequência de tabulação.
  final IconData? suffixIcon;
  final VoidCallback? onSuffixPressed;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: controller,
      obscureText: obscureText,
      readOnly: readOnly,
      autofocus: autofocus,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffixIcon == null
            ? null
            : (onSuffixPressed != null
                ? ExcludeFocusTraversal(
                    child: IconButton(icon: Icon(suffixIcon), onPressed: onSuffixPressed),
                  )
                : Icon(suffixIcon)),
      ),
    );
    return readOnly ? ExcludeFocusTraversal(child: field) : field;
  }
}
