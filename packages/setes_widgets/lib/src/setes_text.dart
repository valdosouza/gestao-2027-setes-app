import 'package:flutter/material.dart';

/// Encapsula [Text] (decisão 11 — ex. canônico do prompt: Text → SetesText).
class SetesText extends StatelessWidget {
  const SetesText(
    this.data, {
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    super.key,
  });

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  /// Título de seção — usa o Theme, nunca cor hardcoded.
  factory SetesText.title(String data, {Key? key}) =>
      SetesText(data, key: key, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600));

  @override
  Widget build(BuildContext context) => Text(
        data,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
}
