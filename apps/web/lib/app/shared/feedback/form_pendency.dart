import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'feedback.dart';

/// Mecânica UMA-PENDÊNCIA-POR-VEZ (R3) para formulários HÍBRIDOS — os que
/// vivem fora da fábrica RegisterFormPage (contratos, contas bancárias,
/// abas da cadeia fiscal, dialogs de sub-lista...). A fábrica embute a
/// MESMA mecânica; aqui ela vira peça reutilizável (Onda B do Framework
/// de Mensagens, prompt_framework_mensagens_validacao.md).

/// Um campo participante da validação, NA ORDEM em que aparece na tela.
class PendencyField {
  const PendencyField({
    required this.name,
    required this.validate,
    this.focusNode,
    this.fieldKey,
    this.beforeFocus,
  });

  /// Nome do campo no PAYLOAD (camelCase) — casa com o `fields[]` do
  /// envelope de erro do servidor ([showServerFieldFeedback]).
  final String name;

  /// Devolve a pendência (chave i18n ou texto já traduzido — a mecânica
  /// aplica .tr(), inócuo em texto pronto) ou null se o campo está ok.
  /// Lê o valor de onde ele mora (controller/estado da página).
  final String? Function() validate;

  /// Foco programático após o OK do dialog (campos de texto).
  final FocusNode? focusNode;

  /// Marca SÓ este campo inline (o SetesTextField precisa ter validator
  /// equivalente) — nunca a tela inteira vermelha (R3).
  final GlobalKey<FormFieldState<String>>? fieldKey;

  /// Prepara a tela para o foco — ex.: forms COMPOSTOS por abas trocam para
  /// a aba do campo aqui. Roda após o OK do dialog, ANTES do requestFocus;
  /// quando presente, marca/foco são adiados um frame (a aba de destino
  /// precisa montar o campo primeiro).
  final VoidCallback? beforeFocus;
}

/// R3 — percorre os campos NA ORDEM declarada; na PRIMEIRA pendência mostra
/// o dialog da ponte → OK → marca e foca SÓ o campo, e devolve false (o
/// salvar aborta; corrigiu, o próximo salvar mostra a próxima pendência).
/// Sem pendências devolve true.
Future<bool> ensureNoPendency(
    BuildContext context, List<PendencyField> fields) async {
  for (final field in fields) {
    final message = field.validate();
    if (message == null) continue;
    await showValidationFeedback(context, message.tr());
    if (context.mounted) _markAndFocus(field);
    return false;
  }
  return true;
}

/// Marca e foca SÓ o campo apontado; com [PendencyField.beforeFocus] (troca
/// de aba) o foco é adiado para o frame seguinte — o campo pode estar em
/// outra aba, desmontado até a troca acontecer.
void _markAndFocus(PendencyField field) {
  final beforeFocus = field.beforeFocus;
  if (beforeFocus == null) {
    field.fieldKey?.currentState?.validate(); // marca SÓ ele
    field.focusNode?.requestFocus();
    return;
  }
  beforeFocus();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    field.fieldKey?.currentState?.validate();
    field.focusNode?.requestFocus();
  });
}

/// Equivalente local do `showServerFieldError` da fábrica para forms
/// híbridos: ancora o `fields[]` do envelope 400/409 no campo — dialog com
/// a message do servidor → OK → [PendencyField.beforeFocus] (aba certa) +
/// foco no campo apontado. Sem correspondência (ou sem fields[]) → feedback
/// genérico da ponte. Sem validate() inline: a regra é do servidor e a
/// marca vermelha local ficaria mentirosa.
Future<void> showServerFieldFeedback(
  BuildContext context,
  Failure failure,
  List<PendencyField> fields,
) async {
  if (failure.fields.isEmpty) return showFailureFeedback(context, failure);

  final serverField = failure.fields.first;
  PendencyField? match;
  for (final field in fields) {
    if (field.name == serverField.field) {
      match = field;
      break;
    }
  }
  if (match == null) return showFailureFeedback(context, failure);
  final anchored = match;

  await showValidationFeedback(context, serverField.message.tr());
  if (!context.mounted) return;
  final beforeFocus = anchored.beforeFocus;
  if (beforeFocus == null) {
    anchored.focusNode?.requestFocus();
    return;
  }
  beforeFocus();
  WidgetsBinding.instance
      .addPostFrameCallback((_) => anchored.focusNode?.requestFocus());
}
