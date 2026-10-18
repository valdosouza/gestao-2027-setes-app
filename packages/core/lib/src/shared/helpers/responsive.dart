import 'package:flutter/material.dart';

/// Helper canônico de responsividade (decisão 5 — padrão weberpsetes).
/// Breakpoints: mobile < 850, tablet 850–1099, desktop >= 1100.
/// Cada tela mantém arquivos page/content separados por breakpoint.
///
/// O [build] mede a ÁREA ÚTIL do widget (`LayoutBuilder`), não a janela — onda D da densidade
/// (`Infra-IA/prompts/prompt_densidade_layout_web.md`): dentro do shell, a área de uma tela é a janela menos o menu.
///
/// ⚠️ CONHECIMENTO NEGATIVO: [Responsive] devolve árvores DIFERENTES de cada lado do breakpoint — ao cruzá-lo (maximizar ou
/// restaurar a janela), tudo o que está dentro nasce de novo e perde o estado. NUNCA o use em volta de quem guarda estado que o
/// usuário não pode perder (um `RouterOutlet` com a tela aberta, um formulário em edição): ali vale UMA árvore adaptativa, em que
/// só o conteúdo de alguns espaços muda com a largura (moldes: `ContentHome` do shell da casa no app web e `ContentLogin` do
/// core). Desde 2026-10-18 nenhuma tela usa este helper — os dois últimos consumidores (shell e login) eram exatamente o caso
/// proibido acima.
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

  // As três consultas abaixo medem a JANELA (MediaQuery); para escolher layout, prefira o [build] (área útil).
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 850;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width < 1100 &&
      MediaQuery.of(context).size.width >= 850;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1100;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final double width = constraints.maxWidth;
        if (width >= 1100) return desktop;
        if (width >= 850 && tablet != null) return tablet!;
        return mobile;
      });
}
