import 'package:flutter/material.dart';

import 'setes_button.dart';
import 'setes_text.dart';

/// Framework de Mensagens (prompt_framework_mensagens_validacao.md):
/// severidade da mensagem — o CANAL deriva dela em UM lugar
/// ([showSetesMessage]): sucesso = SnackBar (R1), o resto = dialog modal.
enum SetesMessageKind { success, info, validation, error }

/// Retorno TIPADO de [showSetesDecision] (R4): Sim gera uma ação, Não gera
/// OUTRA ação, Cancelar = indeciso — nada acontece.
enum SetesDecision { yes, no, cancel }

/// Apresentador único de mensagens do design system (peça E).
///
/// A tela NUNCA escolhe o canal: entrega o desfecho com a severidade e o
/// canal deriva aqui — [SetesMessageKind.success] vira SnackBar (sem exigir
/// clique, R1); info/validation/error viram AlertDialog modal com botão OK.
///
/// Design system SEM easy_localization: [message], [title], [okLabel] e
/// [refText] chegam PRONTOS (já traduzidos) — a ponte do app traduz.
/// [refText] (só para [SetesMessageKind.error]): linha discreta com o código
/// de rastro do suporte (ref da tb_crashlytics).
Future<void> showSetesMessage(
  BuildContext context, {
  required SetesMessageKind kind,
  required String message,
  required String okLabel,
  String? title,
  String? refText,
}) async {
  if (kind == SetesMessageKind.success) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: SetesText(message)));
    return;
  }

  final theme = Theme.of(context);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: title == null ? null : SetesText(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SetesText(message),
          if (kind == SetesMessageKind.error && refText != null) ...[
            const SizedBox(height: 12),
            SetesText(
              refText,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
      actions: [
        SetesButton(
          label: okLabel,
          kind: SetesButtonKind.text,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
      ],
    ),
  );
}

/// Pergunta com decisão 3-way tipada (R4). Fechar pelo barrier/ESC = cancel.
/// [noLabel] null = pergunta sem ação alternativa (só Sim/Cancelar — ex.:
/// confirmação de exclusão). Labels chegam PRONTOS (traduzidos pela ponte).
Future<SetesDecision> showSetesDecision(
  BuildContext context, {
  required String message,
  required String yesLabel,
  required String cancelLabel,
  String? title,
  String? noLabel,
}) async {
  final decision = await showDialog<SetesDecision>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: title == null ? null : SetesText(title),
      content: SetesText(message),
      actions: [
        SetesButton(
          label: cancelLabel,
          kind: SetesButtonKind.text,
          onPressed: () => Navigator.of(dialogContext).pop(SetesDecision.cancel),
        ),
        if (noLabel != null)
          SetesButton(
            label: noLabel,
            kind: SetesButtonKind.text,
            onPressed: () => Navigator.of(dialogContext).pop(SetesDecision.no),
          ),
        SetesButton(
          label: yesLabel,
          kind: SetesButtonKind.text,
          onPressed: () => Navigator.of(dialogContext).pop(SetesDecision.yes),
        ),
      ],
    ),
  );
  return decision ?? SetesDecision.cancel;
}
