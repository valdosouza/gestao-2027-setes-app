import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixPressed,
    this.hint,
    this.maxLines = 1,
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

  /// Máscaras/filtros de digitação (ex.: SetesMaskFormatter do
  /// setes_validators — Fase 2 campos configuráveis).
  final List<TextInputFormatter>? inputFormatters;

  /// Notifica cada alteração de texto (ex.: abas que editam um draft no bloc).
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final IconData? prefixIcon;

  /// Ícone à direita; com [onSuffixPressed] vira botão (ex.: Icons.search).
  /// O botão não entra na sequência de tabulação.
  final IconData? suffixIcon;
  final VoidCallback? onSuffixPressed;
  final String? hint;

  /// >1 = campo de texto longo (ex.: Aplicação do CFOP). Incompatível com
  /// [obscureText] (regra do próprio TextFormField).
  final int maxLines;

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
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      maxLines: obscureText ? 1 : maxLines,
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
