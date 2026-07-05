import 'package:flutter/material.dart';

/// Helper canônico de responsividade (decisão 5 — padrão weberpsetes).
/// Breakpoints: mobile < 850, tablet 850–1099, desktop >= 1100.
/// Cada tela mantém arquivos page/content separados por breakpoint.
class Responsive extends StatelessWidget {
  const Responsive({
    required this.mobile,
    required this.desktop,
    this.tablet,
    super.key,
  });

  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 850;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width < 1100 &&
      MediaQuery.of(context).size.width >= 850;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1100;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    if (width >= 1100) return desktop;
    if (width >= 850 && tablet != null) return tablet!;
    return mobile;
  }
}
