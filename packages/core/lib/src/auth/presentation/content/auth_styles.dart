import 'package:flutter/material.dart';

/// Estilo visual das telas de auth (referência: weberpsetes auth_page +
/// theme.dart kBoxDecoration*). As cores DERIVAM do tema vigente
/// (decisão 27) — nada hardcoded: mudou a primária, o degradê acompanha.
class AuthStyles {
  const AuthStyles._();

  /// Degradê de fundo (kBoxDecorationflexibleSpace do weberpsetes,
  /// derivado da primária do tema).
  static BoxDecoration background(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(primary, Colors.white, 0.35)!,
          Color.lerp(primary, Colors.white, 0.15)!,
          primary,
          Color.lerp(primary, Colors.black, 0.20)!,
        ],
        stops: const [0.1, 0.4, 0.7, 0.9],
      ),
    );
  }

  /// Caixa translúcida dos campos (kBoxDecorationStyle).
  static BoxDecoration field(BuildContext context) => BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6.0, offset: Offset(0, 2)),
        ],
      );

  static const TextStyle label = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle input = TextStyle(color: Colors.white);

  static const TextStyle hint = TextStyle(color: Colors.white70);
}
