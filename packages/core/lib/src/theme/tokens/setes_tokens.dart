import 'package:flutter/material.dart';

/// Marcadores semânticos do tema (decisão 27 — modelo THEME_EXAMPLE.md):
/// as telas NUNCA definem cor; referenciam um marcador. Trocar o aspecto
/// do sistema = trocar os valores aqui (via tema da institution).
///
/// Uso: `context.tokens.brandPrimary`, `context.tokens.success`...
class SetesTokens extends ThemeExtension<SetesTokens> {
  const SetesTokens({
    required this.brandPrimary,
    required this.brandSecondary,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.menuBackground,
    required this.menuSelected,
  });

  /// Identidade visual da institution (tb_institution_theme)
  final Color brandPrimary;
  final Color brandSecondary;

  /// Semânticas fixas do design system
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  /// Derivadas — shell de menus
  final Color menuBackground;
  final Color menuSelected;

  @override
  SetesTokens copyWith({
    Color? brandPrimary,
    Color? brandSecondary,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? menuBackground,
    Color? menuSelected,
  }) =>
      SetesTokens(
        brandPrimary: brandPrimary ?? this.brandPrimary,
        brandSecondary: brandSecondary ?? this.brandSecondary,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        danger: danger ?? this.danger,
        info: info ?? this.info,
        menuBackground: menuBackground ?? this.menuBackground,
        menuSelected: menuSelected ?? this.menuSelected,
      );

  @override
  SetesTokens lerp(ThemeExtension<SetesTokens>? other, double t) {
    if (other is! SetesTokens) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return SetesTokens(
      brandPrimary: l(brandPrimary, other.brandPrimary),
      brandSecondary: l(brandSecondary, other.brandSecondary),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      danger: l(danger, other.danger),
      info: l(info, other.info),
      menuBackground: l(menuBackground, other.menuBackground),
      menuSelected: l(menuSelected, other.menuSelected),
    );
  }
}

extension SetesTokensContext on BuildContext {
  /// Acesso curto aos marcadores: `context.tokens.brandPrimary`
  SetesTokens get tokens => Theme.of(this).extension<SetesTokens>()!;
}
