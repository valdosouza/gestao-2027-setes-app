import 'package:flutter/material.dart';

/// Tamanho de um campo na [SetesFormGrid] (onda B da densidade — 2026-10-17).
///
/// O tamanho diz QUANTO o conteúdo do campo precisa, nunca a largura em
/// pixels: a grade decide a largura pela área DISPONÍVEL.
/// - [small]  — códigos, datas, documentos, valores (CNPJ, UF, alíquota)
/// - [medium] — textos curtos e listas de apoio (cidade, estado, e-mail)
/// - [large]  — nomes e descrições (razão social, descrição do serviço)
/// - [full]   — linha inteira (texto longo, seções, grupos de opções)
enum SetesFieldSize { small, medium, large, full }

/// Um item da [SetesFormGrid]: o widget do campo + o tamanho dele.
class SetesFormGridItem {
  const SetesFormGridItem({
    required this.child,
    this.size = SetesFieldSize.large,
  });

  final Widget child;
  final SetesFieldSize size;
}

/// Grade responsiva de formulário (onda B da densidade — 2026-10-17).
///
/// Substitui a coluna única de campos esticados na largura da janela:
/// - 12 colunas medidas pela largura DISPONÍVEL (LayoutBuilder), não pela
///   janela — o menu lateral aberto conta;
/// - faixas de largura do Material 3 (compacta < 600, média < 840,
///   expandida ≥ 840); na compacta todo campo ocupa a linha inteira (o
///   celular fica como era);
/// - largura máxima [maxWidth], alinhada à esquerda, para o formulário não
///   esticar em monitor grande;
/// - os itens entram na ORDEM declarada, linha a linha (quebra quando o
///   próximo não cabe) — a ordem de leitura e a de Tab seguem iguais.
class SetesFormGrid extends StatelessWidget {
  const SetesFormGrid({
    required this.items,
    this.maxWidth = maxContentWidth,
    this.spacing = 16,
    this.runSpacing = 16,
    super.key,
  });

  /// Largura máxima padrão do conteúdo de um formulário.
  static const double maxContentWidth = 1200;

  /// Faixas de largura (Material 3 window size classes), aplicadas à área
  /// disponível para a grade.
  static const double mediumBreakpoint = 600;
  static const double expandedBreakpoint = 840;

  static const int columns = 12;

  final List<SetesFormGridItem> items;
  final double maxWidth;

  /// Espaço horizontal entre campos da mesma linha.
  final double spacing;

  /// Espaço vertical entre linhas.
  final double runSpacing;

  /// Colunas (de 12) ocupadas por [size] numa grade de largura [width].
  static int spanOf(SetesFieldSize size, double width) {
    if (width < mediumBreakpoint) return columns;
    final expanded = width >= expandedBreakpoint;
    return switch (size) {
      SetesFieldSize.small => expanded ? 3 : 4,
      SetesFieldSize.medium => expanded ? 4 : 6,
      SetesFieldSize.large => expanded ? 6 : 12,
      SetesFieldSize.full => columns,
    };
  }

  @override
  Widget build(BuildContext context) => Align(
        alignment: AlignmentDirectional.topStart,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: LayoutBuilder(builder: _buildRows),
        ),
      );

  Widget _buildRows(BuildContext context, BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final columnWidth = (width - spacing * (columns - 1)) / columns;

    // Distribui os itens em linhas, na ordem declarada.
    final rows = <List<(SetesFormGridItem, int)>>[];
    var used = columns;
    for (final item in items) {
      final span = spanOf(item.size, width);
      if (used + span > columns) {
        rows.add([]);
        used = 0;
      }
      rows.last.add((item, span));
      used += span;
    }

    // floor: a soma das larguras nunca passa da linha por arredondamento.
    double widthOf(int span) =>
        (columnWidth * span + spacing * (span - 1)).floorToDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, row) in rows.indexed) ...[
          if (index > 0) SizedBox(height: runSpacing),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (position, (item, span)) in row.indexed) ...[
                if (position > 0) SizedBox(width: spacing),
                SizedBox(width: widthOf(span), child: item.child),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
