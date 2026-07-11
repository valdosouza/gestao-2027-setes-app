import 'package:flutter/material.dart';

import 'tokens/setes_tokens.dart';

/// Marcadores estáticos da marca (decisão 27 — estilo AppColors do
/// THEME_EXAMPLE.md). Identidade extraída do material oficial Setes
/// (logomarca/flyer) + neutros do weberpsetes (theme.dart).
class SetesColors {
  const SetesColors._();

  // Identidade Setes
  static const Color blue       = Color(0xFF2E6DA4); // azul do "7" da logomarca redonda — PRIMÁRIA padrão
  static const Color green      = Color(0xFF3E9B4F); // verde da marca (círculo/faixas) — apoio/destaques
  static const Color greenDark  = Color(0xFF2E7D32); // gradientes/hover
  static const Color navy       = Color(0xFF1B3A5F); // títulos e faixa institucional

  // Neutros estruturais (weberpsetes: kBgLightColor/kSecondaryColor/k*TextColor)
  static const Color bgLight    = Color(0xFFF2F4FC); // fundo geral
  static const Color bgDark     = Color(0xFFEBEDFA);
  static const Color surface    = Color(0xFFF5F6FC); // cartões/menus
  static const Color gray       = Color(0xFF8793B2); // ícones/secundários
  static const Color titleText  = Color(0xFF30384D);
  static const Color bodyText   = Color(0xFF4D5875);

  // Semânticas
  static const Color success    = Color(0xFF4CAF50);
  static const Color warning    = Color(0xFFFFC107);
  static const Color danger     = Color(0xFFE53935);
  static const Color info       = Color(0xFF2196F3);
}

class SetesMetrics {
  const SetesMetrics._();
  static const double padding = 16.0; // kDefaultPadding do weberpsetes
}

/// Fábrica de tema (decisão 27): a WEB usa UM estilo para todos os módulos.
/// Padrão = identidade Setes; o cliente sobrepõe primary/secondary via
/// tb_institution_theme (decisão 16). Todo o resto deriva dos marcadores —
/// nenhuma tela define cor. (Cores por módulo/app — THEME_EXAMPLE — ficam
/// para os apps Android, fases futuras.)
class SetesTheme {
  const SetesTheme._();

  static ThemeData build({Color? primary, Color? secondary}) {
    final Color brandPrimary   = primary ?? SetesColors.blue;   // azul do "7" da logo
    final Color brandSecondary = secondary ?? SetesColors.navy;

    var scheme = ColorScheme.fromSeed(seedColor: brandPrimary).copyWith(
      primary: brandPrimary,
      secondary: brandSecondary,
      surface: SetesColors.surface,
      error: SetesColors.danger,
    );

    final tokens = SetesTokens(
      brandPrimary: brandPrimary,
      brandSecondary: brandSecondary,
      success: SetesColors.success,
      warning: SetesColors.warning,
      danger: SetesColors.danger,
      info: SetesColors.info,
      menuBackground: SetesColors.surface,
      menuSelected: scheme.primaryContainer,
    );

    const baseText = TextTheme();
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: [tokens],
      scaffoldBackgroundColor: SetesColors.bgLight,
      // Faixa da marca: primária com texto branco (flyer Setes)
      appBarTheme: AppBarTheme(
        backgroundColor: brandPrimary,
        foregroundColor: Colors.white,
      ),
      textTheme: baseText.copyWith(
        titleLarge: const TextStyle(
            fontSize: 20, fontWeight: FontWeight.w600, color: SetesColors.titleText),
        titleMedium: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: SetesColors.titleText),
        bodyMedium: const TextStyle(fontSize: 14, color: SetesColors.bodyText),
        bodySmall: const TextStyle(fontSize: 12, color: SetesColors.gray),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Conversão hex ↔ Color (formato da API: #RRGGBB)
  // ------------------------------------------------------------------

  static Color? colorFromHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var value = hex.replaceFirst('#', '');
    if (value.length == 6) value = 'FF$value';
    final parsed = int.tryParse(value, radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  static String colorToHex(Color color) {
    String two(double v) =>
        (v * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0').toUpperCase();
    return '#${two(color.r)}${two(color.g)}${two(color.b)}';
  }
}
